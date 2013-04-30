#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2008-2013 -- leonerd@leonerd.org.uk

package Net::Async::HTTP;

use strict;
use warnings;
use base qw( IO::Async::Notifier );

our $VERSION = '0.20';

our $DEFAULT_UA = "Perl + " . __PACKAGE__ . "/$VERSION";
our $DEFAULT_MAXREDIR = 3;
our $DEFAULT_MAX_IN_FLIGHT = 4;

use Carp;

use Net::Async::HTTP::Protocol;

use HTTP::Request;
use HTTP::Request::Common qw();

use IO::Async::Stream;
use IO::Async::Loop 0.31; # for ->connect( extensions )

use Future::Utils qw( repeat );

use Socket qw( SOCK_STREAM );

use constant HTTP_PORT  => 80;
use constant HTTPS_PORT => 443;

=head1 NAME

C<Net::Async::HTTP> - use HTTP with C<IO::Async>

=head1 SYNOPSIS

 use IO::Async::Loop;
 use Net::Async::HTTP;
 use URI;

 my $loop = IO::Async::Loop->new();

 my $http = Net::Async::HTTP->new();

 $loop->add( $http );

 $http->do_request(
    uri => URI->new( "http://www.cpan.org/" ),

    on_response => sub {
       my ( $response ) = @_;
       print "Front page of http://www.cpan.org/ is:\n";
       print $response->as_string;
       $loop->loop_stop;
    },

    on_error => sub {
       my ( $message ) = @_;
       print "Cannot fetch http://www.cpan.org/ - $message\n";
       $loop->loop_stop;
    },
 );

 $loop->loop_forever;

=head1 DESCRIPTION

This object class implements an asynchronous HTTP user agent. It sends
requests to servers, and invokes continuation callbacks when responses are
received. The object supports multiple concurrent connections to servers, and
allows multiple requests in the pipeline to any one connection. Normally, only
one such object will be needed per program to support any number of requests.

This module optionally supports SSL connections, if L<IO::Async::SSL> is
installed. If so, SSL can be requested either by passing a URI with the
C<https> scheme, or by passing a true value as the C<SSL> parameter.

=cut

sub _init
{
   my $self = shift;

   $self->{connections} = {}; # { "$host:$port" } -> $conn
}

=head1 PARAMETERS

The following named parameters may be passed to C<new> or C<configure>:

=over 8

=item user_agent => STRING

A string to set in the C<User-Agent> HTTP header. If not supplied, one will
be constructed that declares C<Net::Async::HTTP> and the version number.

=item max_redirects => INT

Optional. How many levels of redirection to follow. If not supplied, will
default to 3. Give 0 to disable redirection entirely.

=item max_in_flight => INT

Optional. The maximum number of in-flight requests to allow per host when
pipelining is enabled and supported on that host. If more requests are made
over this limit they will be queued internally by the object and not sent to
the server until responses are received. If not supplied, will default to 4.
Give 0 to disable the limit entirely.

=item timeout => NUM

Optional. How long in seconds to wait before giving up on a request. If not
supplied then no default will be applied, and no timeout will take place.

=item proxy_host => STRING

=item proxy_port => INT

Optional. Default values to apply to each C<request> method.

=item cookie_jar => HTTP::Cookies

Optional. A reference to a L<HTTP::Cookies> object. Will be used to set
cookies in requests and store them from responses.

=item pipeline => BOOL

Optional. If false, disables HTTP/1.1-style request pipelining.

=item local_host => STRING

=item local_port => INT

=item local_addrs => ARRAY

=item local_addr => HASH or ARRAY

Optional. Parameters to pass on to the C<connect> method used to connect
sockets to HTTP servers. Sets the local socket address to C<bind()> to. For
more detail, see the documentation in L<IO::Async::Connector>.

=back

=cut

sub configure
{
   my $self = shift;
   my %params = @_;

   foreach (qw( user_agent max_redirects max_in_flight
      timeout proxy_host proxy_port cookie_jar pipeline local_host local_port
      local_addrs local_addr ))
   {
      $self->{$_} = delete $params{$_} if exists $params{$_};
   }

   $self->SUPER::configure( %params );

   defined $self->{user_agent}    or $self->{user_agent}    = $DEFAULT_UA;
   defined $self->{max_redirects} or $self->{max_redirects} = $DEFAULT_MAXREDIR;
   defined $self->{max_in_flight} or $self->{max_in_flight} = $DEFAULT_MAX_IN_FLIGHT;
   defined $self->{pipeline}      or $self->{pipeline}      = 1;
}

=head1 METHODS

=cut

sub get_connection
{
   my $self = shift;
   my %args = @_;

   my $loop = $self->get_loop or croak "Cannot ->get_connection without a Loop";

   my $host = delete $args{host};
   my $port = delete $args{port};

   my $connections = $self->{connections};
   my $key = "$host:$port";
   $key .= int(rand(100));

   if( my $conn = $connections->{$key} ) {
      return $conn->new_ready_future;
   }

   my $conn = Net::Async::HTTP::Protocol->new(
      notifier_name => $key,
      max_in_flight => $self->{max_in_flight},
      pipeline => $self->{pipeline},
      on_closed => sub {
         my $conn = shift;

         $conn->remove_from_parent;
         delete $connections->{$key};
      },
   );

   $self->add_child( $conn );

   $connections->{$key} = $conn;

   my $f = $conn->new_ready_future;

   if( $args{SSL} ) {
      require IO::Async::SSL;
      IO::Async::SSL->VERSION( 0.04 );

      push @{ $args{extensions} }, "SSL";

      $args{on_ssl_error} = sub {
         delete $connections->{$key};
         $f->fail( "$host:$port SSL error [$_[0]]" );
      };
   }

   $conn->connect(
      host     => $host,
      service  => $port,

      on_resolve_error => sub {
         delete $connections->{$key};
         $f->fail( "$host:$port not resolvable [$_[0]]" );
      },

      on_connect_error => sub {
         delete $connections->{$key};
         $f->fail( "$host:$port not contactable [$_[-1]]" );
      },

      %args,

      ( map { defined $self->{$_} ? ( $_ => $self->{$_} ) : () } qw( local_host local_port local_addrs local_addr ) ),
   );

   return $f;
}

=head2 $http->do_request( %args )

Send an HTTP request to a server, and set up the callbacks to receive a reply.
The request may be represented by an L<HTTP::Request> object, or a L<URI>
object, depending on the arguments passed.

The following named arguments are used for C<HTTP::Request>s:

=over 8

=item request => HTTP::Request

A reference to an C<HTTP::Request> object

=item host => STRING

Hostname of the server to connect to

=item port => INT or STRING

Optional. Port number or service of the server to connect to. If not defined,
will default to C<http> or C<https> depending on whether SSL is being used.

=item SSL => BOOL

Optional. If true, an SSL connection will be used.

=back

The following named arguments are used for C<URI> requests:

=over 8

=item uri => URI

A reference to a C<URI> object. If the scheme is C<https> then an SSL
connection will be used.

=item method => STRING

Optional. The HTTP method. If missing, C<GET> is used.

=item content => STRING or ARRAY ref

Optional. The body content to use for C<POST> requests. If this is a plain
scalar instead of an ARRAY ref, it will not be form encoded. In this case, a
C<content_type> field must also be supplied to describe it.

=item request_body => CODE or STRING

Optional. Allows request body content to be generated by a callback, rather
than being provided as part of the C<request> object. This can either be a
C<CODE> reference to a generator function, or a plain string.

As this is passed to the underlying L<IO::Async::Stream> C<write> method, the
usual semantics apply here. If passed a C<CODE> reference, it will be called
repeatedly whenever it's safe to write. The code should should return C<undef>
to indicate completion.

As with the C<content> parameter, the C<content_type> field should be
specified explicitly in the request header, as should the content length
(typically via the L<HTTP::Request> C<content_length> method). See also
F<examples/PUT.pl>.

=item content_type => STRING

The type of non-form data C<content>.

=item user => STRING

=item pass => STRING

Optional. If both are given, the HTTP Basic Authorization header will be sent
with these details.

=item proxy_host => STRING

=item proxy_port => INT

Optional. Override the hostname or port number implied by the URI.

=back

For either request type, it takes the following continuation callbacks:

=over 8

=item on_response => CODE

A callback that is invoked when a response to this request has been received.
It will be passed an L<HTTP::Response> object containing the response the
server sent.

 $on_response->( $response )

=item on_header => CODE

Alternative to C<on_response>. A callback that is invoked when the header of a
response has been received. It is expected to return a C<CODE> reference for
handling chunks of body content. This C<CODE> reference will be invoked with
no arguments once the end of the request has been reached.

 $on_body_chunk = $on_header->( $header )

    $on_body_chunk->( $data )
    $on_body_chunk->()

=item on_error => CODE

A callback that is invoked if an error occurs while trying to send the request
or obtain the response. It will be passed an error message.

 $on_error->( $message )

=item on_redirect => CODE

Optional. A callback that is invoked if a redirect response is received,
before the new location is fetched. It will be passed the response and the new
URL.

 $on_redirect->( $response, $location )

=item max_redirects => INT

Optional. How many levels of redirection to follow. If not supplied, will
default to the value given in the constructor.

=item timeout => NUM

Optional. Specifies a timeout in seconds, after which to give up on the
request and fail it with an error. If this happens, the error message will be
C<Timed out>.

=back

=head2 $future = $http->do_request( %args )

This method also returns a L<Future>, which will eventually yield the (final
non-redirect) C<HTTP::Response>. If returning a future, then the
C<on_response>, C<on_header> and C<on_error> callbacks are optional.

=cut

sub _do_one_request
{
   my $self = shift;
   my %args = @_;

   my $host    = delete $args{host};
   my $port    = delete $args{port};
   my $request = delete $args{request};

   $self->prepare_request( $request );

   return $self->get_connection(
      host => $args{proxy_host} || $self->{proxy_host} || $host,
      port => $args{proxy_port} || $self->{proxy_port} || $port,
      SSL  => $args{SSL},
      ( map { m/^SSL_/ ? ( $_ => $args{$_} ) : () } keys %args ),
   )->and_then( sub {
      my ( $f ) = @_;

      my ( $conn ) = $f->get;

      return $conn->request(
         request => $request,
         %args,
      );
   } );
}

sub _do_request
{
   my $self = shift;
   my %args = @_;

   my $host = $args{host};
   my $port = $args{port};
   my $ssl  = $args{SSL};

   my $on_header = delete $args{on_header};

   my $redirects = defined $args{max_redirects} ? $args{max_redirects} : $self->{max_redirects};

   my $request = $args{request};
   my $response;
   my $reqf;
   # Defeat prototype
   my $future = &repeat( $self->_capture_weakself( sub {
      my $self = shift;
      my ( $previous_f ) = @_;

      if( $previous_f ) {
         my $previous_response = $previous_f->get;
         $args{previous_response} = $previous_response;

         my $location = $previous_response->header( "Location" );

         if( $location =~ m{^http(?:s?)://} ) {
            # skip
         }
         elsif( $location =~ m{^/} ) {
            my $hostport = ( $port != HTTP_PORT ) ? "$host:$port" : $host;
            $location = "http://$hostport" . $location;
         }
         else {
            return $self->loop->new_future->fail( "Unrecognised Location: $location" );
         }

         my $loc_uri = URI->new( $location );
         unless( $loc_uri ) {
            return $self->loop->new_future->fail( "Unable to parse '$location' as a URI" );
         }

         $args{on_redirect}->( $previous_response, $location ) if $args{on_redirect};

         %args = $self->_make_request_for_uri( $loc_uri, %args );
      }

      my $uri = $request->uri;
      if( defined $uri->scheme and $uri->scheme =~ m/^http(s?)$/ ) {
         $host = $uri->host if !defined $host;
         $port = $uri->port if !defined $port;
         $ssl = ( $uri->scheme eq "https" );
      }

      defined $host or croak "Expected 'host'";
      defined $port or $port = ( $ssl ? HTTPS_PORT : HTTP_PORT );

      return $reqf = $self->_do_one_request(
         host => $host,
         port => $port,
         %args,
         on_header => $self->_capture_weakself( sub {
            my $self = shift;
            ( $response ) = @_;

            return $on_header->( $response ) unless $response->is_redirect;

            # Consume and discard the entire body of a redirect
            return sub {
               return if @_;
               return $response;
            };
         } ),
      );
   } ),
   while => sub {
      my $f = shift;
      return 0 if $f->failure or $f->is_cancelled;
      return $response->is_redirect && $redirects--;
   },
   return => $self->loop->new_future );

   return $future;
}

sub do_request
{
   my $self = shift;
   my %args = @_;

   if( my $uri = delete $args{uri} ) {
      %args = $self->_make_request_for_uri( $uri, %args );
   }

   if( $args{on_header} ) {
      # ok
   }
   elsif( my $on_response = delete $args{on_response} or defined wantarray ) {
      $args{on_header} = sub {
         my ( $response ) = @_;
         return sub {
            if( @_ ) {
               $response->add_content( @_ );
            }
            else {
               $on_response->( $response ) if $on_response;
               return $response;
            }
         };
      }
   }
   else {
      croak "Expected 'on_response' or 'on_header' as CODE ref or to return a Future";
   }

   my $timeout = defined $args{timeout} ? $args{timeout} : $self->{timeout};

   my $future = $self->_do_request( %args );

   if( defined $timeout ) {
      $future = Future->wait_any(
         $future,
         $self->loop->timeout_future( after => $timeout )
                    ->transform( fail => sub { "Timed out" } ),
      );
   }

   $future->on_done( $self->_capture_weakself( sub {
      my $self = shift;
      my $response = shift;
      $self->process_response( $response );
   } ) );

   $future->on_fail( $args{on_error} ) if $args{on_error};

   # DODGY HACK:
   # In void context we'll lose reference on the ->wait_any Future, so the
   # timeout logic will never happen. So lets purposely create a cycle by
   # capturing the $future in on_done/on_fail closures within itself. This
   # conveniently clears them out to drop the ref when done.
   if( !defined wantarray and $args{on_header} || $args{on_response} || $args{on_error} ) {
      $future->on_done( sub { undef $future } );
      $future->on_fail( sub { undef $future } );
   }

   return $future;
}

sub _make_request_for_uri
{
   my $self = shift;
   my ( $uri, %args ) = @_;

   ref $uri and $uri->isa( "URI" ) or croak "Expected 'uri' as a URI reference";

   my $method = delete $args{method} || "GET";

   $args{host} = $uri->host;
   $args{port} = $uri->port;
   $args{SSL}  = ( $uri->scheme eq "https" );

   my $request;

   if( $method eq "POST" ) {
      defined $args{content} or croak "Expected 'content' with POST method";

      # Lack of content_type didn't used to be a failure condition:
      ref $args{content} or defined $args{content_type} or
      carp "No 'content_type' was given with 'content'";

      # This will automatically encode a form for us
      $request = HTTP::Request::Common::POST( $uri, Content => $args{content}, Content_Type => $args{content_type} );
   }
   else {
      $request = HTTP::Request->new( $method, $uri );
   }

   $request->protocol( "HTTP/1.1" );
   $request->header( Host => $uri->host );

   my ( $user, $pass );

   if( defined $uri->userinfo ) {
      ( $user, $pass ) = split( m/:/, $uri->userinfo, 2 );
   }
   elsif( defined $args{user} and defined $args{pass} ) {
      $user = $args{user};
      $pass = $args{pass};
   }

   if( defined $user and defined $pass ) {
      $request->authorization_basic( $user, $pass );
   }

   $args{request} = $request;

   return %args;
}

=head2 $future = $http->GET( $uri, %args )

=head2 $future = $http->HEAD( $uri, %args )

Convenient wrappers for using the C<GET> or C<HEAD> methods with a C<URI>
object and few if any other arguments, returning a C<Future>.

=cut

sub GET
{
   my $self = shift;
   return $self->do_request( method => "GET", uri => @_ );
}

sub HEAD
{
   my $self = shift;
   return $self->do_request( method => "HEAD", uri => @_ );
}

=head1 SUBCLASS METHODS

The following methods are intended as points for subclasses to override, to
add extra functionallity.

=cut

=head2 $http->prepare_request( $request )

Called just before the C<HTTP::Request> object is sent to the server.

=cut

sub prepare_request
{
   my $self = shift;
   my ( $request ) = @_;

   $request->init_header( 'User-Agent' => $self->{user_agent} ) if length $self->{user_agent};
   $request->init_header( "Connection" => "keep-alive" );

   $self->{cookie_jar}->add_cookie_header( $request ) if $self->{cookie_jar};
}

=head2 $http->process_response( $response )

Called after a non-redirect C<HTTP::Response> has been received from a server.
The originating request will be set in the object.

=cut

sub process_response
{
   my $self = shift;
   my ( $response ) = @_;

   $self->{cookie_jar}->extract_cookies( $response ) if $self->{cookie_jar};
}

=head1 EXAMPLES

=head2 Concurrent GET

The C<Future>-returning C<GET> method makes it easy to await multiple URLs at
once.

 my @URLs = ( ... );

 my $http = Net::Async::HTTP->new( ... );
 $loop->add( $http );

 my $future = Future->wait_all(
    map {
       my $url = $_;
       $http->GET( $url )
            ->on_done( sub {
               my $response = shift;
               say "$url succeeded: ", $response->code;
               say "  Content-Type":", $response->content_type;
            } )
            ->on_fail( sub {
               my $failure = shift;
               say "$url failed: $failure";
            } );
    } @URLs
 );

 $loop->await( $future );

=cut

=head1 SEE ALSO

=over 4

=item *

L<http://tools.ietf.org/html/rfc2616> - Hypertext Transfer Protocol -- HTTP/1.1

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;

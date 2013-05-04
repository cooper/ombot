#!/usr/bin/env perl
# Omegle IRC bot by Matthew Barksdale 
# Version: 0.1-dev

use strict;
use warnings;
use feature qw(say switch);

BEGIN {
    our $Bin;
    use FindBin qw($Bin);
    unshift(@INC,
        "$Bin/../lib",
        "$Bin/../lib/evented-object",
        "$Bin/../lib/evented-configuration",
        "$Bin/../lib/net-async-omegle",
        "$Bin/../lib/libirc/lib"
    );
}

use IO::Async;
use IO::Async::Loop;
use IO::Async::Stream;

use Net::Async::HTTP;
use URI;

use EventedObject;
use Evented::Configuration;
use Net::Async::Omegle;
use IRC;
use IRC::Async;

my (
    $loop,              # IO::Async loop.
    $irc,               # libirc object.
    $om,                # Net::Async::Omegle object.
    $http,              # Net::Async::HTTP object.
    $bot,               # bot EventedObject.
    $config_file,       # configuration file.
    $config,            # Evented::Configuration object.
    %sessions,          # session objects stored by lc channel.
    @pending_sessions   # sessions pending for ->start().
);

# Config file? Default to bot.conf unless otherwise told
$config_file = $ARGV[0] || "$Bin/../etc/bot.conf";

# Parse Evented::Configuration config file.
$config = Evented::Configuration->new(conffile => $config_file);
$config->parse_config;
sub conf { $config->get(@_) }

# create bot EventedObject.
$bot = EventedObject->new;

# Initialization subroutine
sub bot_init {

    # Create loop
    $loop = IO::Async::Loop->new;
    
    # Create Net::Async::Omegle and Net::Async::HTTP objects.
    $om   = Net::Async::Omegle->new();
    $http = Net::Async::HTTP->new;
    
    # create libirc server object.
    $irc = IRC::Async->new(
        host => conf('irc', 'host'),
        port => conf('irc', 'port'), # TODO: bind address.
        nick => conf('bot', 'nick'),
        user => conf('bot', 'user'),
        real => conf('bot', 'gecos')
    );
    
    # Add these objects to loop.
    $loop->add($om);
    $loop->add($irc);
    $loop->add($http);

    # Request Omegle status information
    $om->update();

    # Attach events to Omegle and IRC objects.
    apply_omegle_handlers($om);
    apply_irc_handlers($irc);
    apply_bot_events($bot);

    # Connect to IRC.
    $irc->connect(on_error => sub { die 'IRC connection error' });
    
    # Let's go
    $loop->run;
    
}


# Attach events to bot object.
sub apply_bot_events {
    my $bot = shift;
    $bot->register_events(
        { command_start             => \&cmd_start              },
        { command_stop              => \&cmd_stop               },
        { command_type              => \&cmd_type               },
        { command_say               => \&cmd_say                },
        { command_count             => \&cmd_count              }
    );
    # TODO: make methods for registering and storing commands.
}

# Attach events to Omegle object.
sub apply_omegle_handlers {
    my $om = shift;
    $om->register_events(
        { done                      => \&sess_done              },
        { waiting                   => \&sess_waiting           },
        { connected                 => \&sess_connected         },
        { common_interests          => \&sess_common_interests  },
        { disconnected              => \&sess_disconnected      },
        { question                  => \&sess_question          },
        { typing                    => \&sess_typing            },
        { stopped_typing            => \&sess_stopped_typing    },
        { message                   => \&sess_message           }
    );
}

# Attach events to IRC object.
sub apply_irc_handlers {
    my $irc = shift;
    
    $irc->{autojoin} = conf('irc', 'autojoin');

    # handle connect.
    $irc->on(end_of_motd => sub {


    });
    
    # handle PRIVMSG.
    $irc->on(privmsg => sub {
        my ($event, $user, $channel, $message) = @_;
        return unless $channel->isa('IRC::Channel'); # ignore PMs.
        
        my $command = lc((split /\s/, $message)[0]);
        $command    =~ m/^\!(\w+)$/ or return; $command = $1;
        my @args    = split /\s/, $message;
        @args       = @args[1..$#args];
        my $sess    = $sessions{$channel};
        
        # fire command.
        $bot->fire("command_$command" => $user, $channel, $sess, @args);
        
    });
    
}

# create and start a new session.
sub cmd_start {
    my ($event, $user, $channel, $sess, @args) = @_;
    
    # check if a session already is running in this channel.
    if ($sess && $sess->running) {
        $channel->send_privmsg('There is already a session in progress.');
        return;
    }
    
    # create a new session.
    $sess = $sessions{$channel} = $om->new;
    $channel->{session} = $sess;
    $sess->{channel}    = $channel;
    
    # if there are arguments, interests were provided.
    if (scalar @args) {
        $sess->{type}   = 'CommonInterests';
        $sess->{topics} = \@args;
    }

    $sess->start;
    $channel->send_privmsg("Starting conversation of type ".$sess->session_type);# XXX
    
}

# stop a session.
sub cmd_stop {
    my ($event, $user, $channel, $sess, @args) = @_;
    
    # check if a session already is running in this channel.
    if (!$sess || !$sess->running) {
        $channel->send_privmsg('No session is currently running.');
        return;
    }
    
    # disconnect from Omegle.
    $sess->disconnect;
    $channel->send_privmsg('You have disconnected.');
    
}

# send a typing event.
sub cmd_type {
    my ($event, $user, $channel, $sess, @args) = @_;
    $sess->type;
    $channel->send_privmsg('You are typing...');
}

# send a message.
sub cmd_say {
    my ($event, $user, $channel, $sess, @args) = @_;
    
    # check if a stranger is present.
    if (!$sess || !$sess->connected) {
        $channel->send_privmsg('No stranger is connected.');
        return;
    }
    
    # send the message.
    my $message = join ' ', @args; # TODO: use the actual message substr'd.
    $channel->send_privmsg("You: $message");
    $sess->say($message);
    
}

# display the user count.
sub cmd_count {
    my ($event, $user, $channel, $sess, @args) = @_;
    $channel->send_privmsg('There are currently '.$om->user_count.' users online.');
}

# waiting on a chat partner.
sub sess_waiting {
    my ($event, $sess) = @_;
    $sess->{channel}->send_privmsg('Looking for someone to chat with. Hang on!');
}

# found a partner.
sub sess_connected {
    my ($event, $sess) = @_;
    $sess->{channel}->send_privmsg('You are now chatting with a random stranger. Say hi!');
}

# received common interests.
sub sess_common_interests {
    my ($event, $sess, @interests) = @_;
    $sess->{channel}->send_privmsg('You and the stranger both like '.join(', ', @interests).q(.));
}

# received question.
sub sess_question {
    my ($event, $sess, $question) = @_;
    $sess->{channel}->send_privmsg("Question: $question");
}

# stranger is typing.
sub sess_typing {
    my ($event, $sess) = @_;
    $sess->{channel}->send_privmsg('Stranger is typing...');
}

# received a message.
sub sess_message {
    my ($event, $sess, $message) = @_;
    $sess->{channel}->send_privmsg("Stranger: $message");
}

# stranger disconnected.
sub sess_disconnected {
    my ($event, $sess) = @_;
    $sess->{channel}->send_privmsg('Your conversational partner has disconnected.');
}

# session ended.
sub sess_done {
    my ($event, $sess) = @_;
    delete $sess->{channel}{session};
    delete $sess->{channel};
}

bot_init();

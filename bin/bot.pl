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
        "$Bin/../lib/api-engine",
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
use API;
use IRC;
use IRC::Async;

use Bot;

our (
    $loop,              # IO::Async loop.
    $api,               # API manager object.
    $irc,               # libirc object.
    $om,                # Net::Async::Omegle object.
    $http,              # Net::Async::HTTP object.
    $bot,               # bot EventedObject.
    $config_file,       # configuration file.
    $config, $conf,     # Evented::Configuration object.
    %sessions,          # session objects stored by lc channel.
    @pending_sessions   # sessions pending for ->start().
);

# Config file? Default to bot.conf unless otherwise told
$config_file = $ARGV[0] || "$Bin/../etc/bot.conf";

# Parse Evented::Configuration config file.
$config = $conf = Evented::Configuration->new(conffile => $config_file);
$config->parse_config;
sub conf { $config->get(@_) }

# create bot object.
$bot = Bot->new;

# Initialization subroutine
sub bot_init {

    # Create loop
    $loop = IO::Async::Loop->new;
    
    # create the API manager object.
    $api = API->new(
        log_sub  => sub { say "[API] ".shift() },
        mod_dir  => "$Bin/../modules",
        base_dir => "$Bin/../lib/API/Base"
    );

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
    
    # load configuration modules.
    load_api_modules();
    
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
}

# Attach events to Omegle object.
sub apply_omegle_handlers {
    my $om = shift;
    $om->register_events(
        { common_interests          => \&sess_common_interests  },
        { question                  => \&sess_question          }
    );
}

# load API modules from configuration.
sub load_api_modules {
    $api->load_module($_) foreach $conf->keys_of_block('modules');
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

bot_init();

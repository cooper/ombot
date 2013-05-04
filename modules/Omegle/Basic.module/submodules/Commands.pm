# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic Omegle conversation commands module
package API::Module::Omegle::Basic::Commands;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'Commands',
    version     => '1.0',
    description => 'provides an IRC interface to basic Omegle functionality',
    requires    => ['Commands'],
    depends     => ['Omegle::Basic'],
    initialize  => \&init
);

# command handlers.
my %commands = (
    start => {
        description => 'start a new conversation',
        callback    => \&cmd_start
    },
    stop => {
        description => 'stops a running session',
        callback    => \&cmd_stop
    },
    type => {
        description => 'sends a typing event',
        callback    => \&cmd_type
    },
    say => {
        description => 'sends a message',
        callback    => \&cmd_say
    },
    count => {
        description => 'displays the online user count',
        callback    => \&cmd_count
    }
);


sub init {

    # register commands.
    foreach (keys %commands) {
        $mod->register_command(command => $_, %{$commands{$_}}) or return;
    }

    return 1;   
}

########################
### COMMAND HANDLERS ###
########################

# create and start a new session.
sub cmd_start {
    my ($event, $user, $channel, $sess, @args) = @_;
    
    # check if a session already is running in this channel.
    if ($sess && $sess->running) {
        $channel->send_privmsg('There is already a session in progress.');
        return;
    }
    
    # create a new session.
    $sess = $main::sessions{$channel} = $main::om->new;
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
    
    # send the message.
    my $message = join ' ', @args; # TODO: use the actual message substr'd.
    $main::bot->om_say($channel, $message);
    
}

# display the user count.
sub cmd_count {
    my ($event, $user, $channel, $sess, @args) = @_;
    $channel->send_privmsg('There are currently '.$main::om->user_count.' users online.');
}

$mod

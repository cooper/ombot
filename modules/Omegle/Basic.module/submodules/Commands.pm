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
    initialize  => \&init
);

# command handlers.
my %commands = (
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
    },
    captcha => {
        description => 'submits a captcha response',
        callback    => \&cmd_captcha
    }
);


sub init {

    # register commands.
    foreach (keys %commands) {
        $mod->register_command(command => $_, %{$commands{$_}}) or return;
    }
    
    # register 100 priority start.
    $mod->register_command(
        command     => 'start',
        priority    => 100,
        callback    => \&cmd_start_100,
        name        => 'omegle.command.100-start',
        description => 'checks if a session is already running'
    );
    
    # register -100 priority start.
    $mod->register_command(
        command     => 'start',
        priority    => -100,
        callback    => \&cmd_start_n100,
        name        => 'omegle.command.-100-start',
        description => 'starts an Omegle conversation'
    );

    return 1;   
}

########################
### COMMAND HANDLERS ###
########################

# create and start a new session.
# this callback with 100 priority will be called before any extensions.
sub cmd_start_100 {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};
    
    # check if a session already is running in this channel.
    if ($sess && $sess->running) {
        $channel->send_privmsg('There is already a session in progress.');
        $event->{stop} = 1; # terminate event.
        return;
    }
    
    # no session is running. continue to execute any additional handlers.
    $event->{sess} = $main::om->new;
    return 1;
    
}

# create and start a new session.
# this callback with -100 priority will be called after any extensions.
sub cmd_start_n100 {
    my ($event, $user, $channel, @args) = @_;
    
    # create a new session if an earlier callback hasn't already.
    my $sess = $event->{sess} || $main::om->new;
    $channel->{sess} = $sess;
    $sess->{channel} = $channel;

    $sess->start;
    $channel->send_privmsg("Starting conversation of type ".$sess->session_type);# XXX

}

# stop a session.
sub cmd_stop {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};
    
    # check if a session already is running in this channel.
    if (!$sess || !$sess->running) {
        $channel->send_privmsg('No session is currently running.');
        $event->{stop} = 1; # terminate event.
        return;
    }
    
    # disconnect from Omegle.
    $sess->disconnect;
    $channel->send_privmsg('You have disconnected.');
    
}

# send a typing event.
sub cmd_type {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};
    
    # not connected.
    $main::bot->om_connected($channel) or return;
    
    $sess->type;
    $channel->send_privmsg('You are typing...');
}

# submit a captcha response.
sub cmd_captcha {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};
    
    # not connected.
    $main::bot->om_running($channel) or return;
    
    $channel->send_privmsg('Verifying...');
    $sess->submit_captcha(join ' ', @args);
    
}

# send a message.
sub cmd_say {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};
    
    # connected check in om_say()

    # send the message.
    my $message = join ' ', @args; # TODO: use the actual message substr'd.
    $main::bot->om_say($channel, $message);
    
}

# display the user count.
sub cmd_count {
    my ($event, $user, $channel, @args) = @_;
    $channel->send_privmsg('There are currently '.$main::om->user_count.' users online.');
}

$mod

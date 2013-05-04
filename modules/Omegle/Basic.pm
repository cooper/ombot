# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic conversation module
package API::Module::Omegle::Basic;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'Omegle::Basic',
    version     => '1.0',
    description => 'provides traditional Omegle chat functionality',
    requires    => ['OmegleEvents', 'Commands'],
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

# Net::Async::Omegle event handlers.
my %omegle_events = (
    done => {
        description => 'a session ended',
        callback    => \&sess_done
    },
    waiting => {
        description => 'waiting on a stranger to connect',
        callback    =>  \&sess_waiting
    },
    connected => {
        description => 'a stranger connected',
        callback    => \&sess_connected
    },
    disconnected => {
        description => 'the stranger disconnected',
        callback    => \&sess_disconnected
    },
    typing => {
        description => 'the stranger began typing',
        callback    => \&sess_typing
    },
    stopped_typing => {
        description => 'the stranger stopped typing',
        callback    => \&sess_stopped_typing
    },
    message => {
        description => 'a message was received from the stranger',
        callback    => \&sess_message
    }
);

sub init {

    # register commands.
    foreach (keys %commands) {
        $mod->register_command(command => $_, %{$commands{$_}}) or return;
    }
    
    # register omegle events.
    foreach (keys %omegle_events) {
        $mod->register_omegle_event(name => $_, %{$omegle_events{$_}}) or return;
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

#############################
### OMEGLE EVENT HANDLERS ###
#############################


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


$mod

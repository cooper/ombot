# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic Omegle events module
package API::Module::Omegle::Basic::Events;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'Events',
    version     => '1.1',
    description => 'handles traditional Omegle events',
    requires    => ['OmegleEvents'],
    initialize  => \&init
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
    },
    server_message => {
        description => 'the server sent a message',
        callback    => \&sess_server_message
    },
    captcha_required => {
        description => 'the server is requesting a captcha verification test',
        callback    => \&sess_captcha_required
    },
    captcha => {
        description => 'a captcha URL was received',
        callback    => \&sess_captcha
    },
    bad_captcha => {
        description => 'the server sent a message',
        callback    => \&sess_bad_captcha
    },
    error => {
        description => 'the server sent an error message',
        callback    => \&sess_error
    }
);


sub init {

    # register omegle events.
    foreach (keys %omegle_events) {
        $mod->register_omegle_event(name => $_, %{$omegle_events{$_}}) or return;
    }

    return 1;   
}

#############################
### OMEGLE EVENT HANDLERS ###
#############################

# server message.
sub sess_server_message {
    my ($event, $sess, $message) = @_;
    $sess->{channel}->send_privmsg($message);
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

# stranger is typing.
sub sess_typing {
    my ($event, $sess) = @_;
    $sess->{channel}->send_privmsg('Stranger is typing...');
}

# stranger stopped typing.
sub sess_stopped_typing {
    my ($event, $sess) = @_;
    $sess->{channel}->send_privmsg('Stranger stopped typing.');
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

# captcha requested.
sub sess_captcha_required {
    my ($event, $sess, $challenge) = @_;
    $sess->{channel}->send_privmsg('The server is requiring human verification test...');
}

# captcha received.
sub sess_captcha {
    my ($event, $sess, $url) = @_;
    $sess->{channel}->send_privmsg("Please verify your humanity: $url");
}

# captcha failed.
sub sess_bad_captcha {
    my ($event, $sess) = @_;
    $sess->{channel}->send_privmsg('Your captcha submission was incorrect.');
}

# server session error.
sub sess_error {
    my ($event, $sess, $message) = @_;
    $sess->{channel}->send_privmsg("Error: $message");
}

$mod

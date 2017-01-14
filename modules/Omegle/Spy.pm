# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Provides Omegle answer and ask (spy) modes
package API::Module::Omegle::Spy;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name          => 'Omegle::Spy',
    version       => '1.0',
    description   => 'allows you to ask an answer questions on Omegle',
    depends_bases => ['OmegleEvents', 'Commands'],
    depends_mods  => ['Omegle::Basic'],
    initialize    => \&init
);

my %omegle_events = (
    question => {
        description => 'a question was asked or will be answered',
        callback    => \&sess_question
    },
    spy_typing => {
        description => 'stranger is typing in spy mode',
        callback    => \&sess_spy_typing
    },
    spy_stopped_typing => {
        description => 'stranger stopped typing in spy mode',
        callback    => \&sess_spy_stopped_typing
    },
    spy_message => {
        description => 'stranger sent message in spy mode',
        callback    => \&sess_spy_message
    },
    spy_disconnected => {
        description => 'stranger disconnected in spy mode',
        callback    => \&sess_spy_disconnected
    }
);

sub init {

    # register omegle events.
    foreach (keys %omegle_events) {
        $mod->register_omegle_event(name => $_, %{$omegle_events{$_}}) or return;
    }

    # register handler for start command.
    $mod->register_command(
        command     => 'start',
        priority    => 0, # halfway between
        callback    => \&cmd_start_0,
        description => 'handles question asking for Omegle'
    ) or return;

    return 1;
}

# received question.
sub sess_question {
    my ($event, $sess, $question) = @_;
    my $str = ::get_format(om_question => { question => $question });
    $sess->{channel}->send_privmsg($str);
}

# spy stranger started typing.
sub sess_spy_typing {
    my ($event, $sess, $which) = @_;
    $sess->{channel}->send_privmsg("Stranger $which is typing...");
}

# spy stranger stopped typing.
sub sess_spy_stopped_typing {
    my ($event, $sess, $which) = @_;
    $sess->{channel}->send_privmsg("Stranger $which stopped typing.");
}

# spy stranger disconnected.
sub sess_spy_disconnected {
    my ($event, $sess, $which) = @_;
    $sess->{channel}->send_privmsg("Stranger $which has disconnected.");
}

# spy stranger said something.
sub sess_spy_message {
    my ($event, $sess, $which, $message) = @_;
    my $msg = ::get_format("om_msg_spy$which" => { message => $message });
    $sess->{channel}->send_privmsg($msg);
}

# start command handler.
sub cmd_start_0 {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $event->{sess};

    # we don't care about this.
    if (!defined $args[0] or lc $args[0] ne '-spy') {
        return 1;
    }

    return 1;
}

$mod

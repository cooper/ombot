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
    
    # register handler 1 for start command.
    $mod->register_command(
        command     => 'start',
        priority    => 0, # halfway between
        callback    => \&cmd_start_0,
        description => 'handles question asking for Omegle'
    ) or return;
    
    # register handler 2 for start command.
    $mod->register_command(
        command     => 'start',
        priority    => 0, # halfway between
        callback    => \&cmd_start_1,
        description => 'handles question answering for Omegle'
    ) or return;
    
    # register 100 priority handler for say command.
    $mod->register_command(
        command     => 'say',
        priority    => 100, # before the builtin
        callback    => \&cmd_say_100,
        description => 'disables say command in Ask mode'
    );
    
    return 1;   
}

# received question.
sub sess_question {
    my ($event, $sess, $question) = @_;
    $sess->{channel}->send_privmsg("Question: $question");
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
    my $str = ::get_format("om_msg_spy$which" => { message => $message });
    $sess->{channel}->send_privmsg($msg);
}

# start command handler.
sub cmd_start_0 {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $event->{sess};
    
    # we don't care about this.
    if (!defined $args[0] or lc $args[0] ne '-ask' && lc $args[0] ne '-question') {
        return 1;
    }

    # no question?
    if (scalar @args < 2) {
        $channel->send_privmsg('Please provide a question.');
        return $event->cancel('omegle.command.-100-start');
    }
    
    # FIXME: use original message.
    my $question = join ' ', @args[1..$#args];

    # set session type and question.
    $sess->{type}     = 'AskQuestion';
    $sess->{question} = $question;
    
    return 1;
}

# start command handler.
sub cmd_start_1 {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $event->{sess};
    
    # we don't care about this.
    if (!defined $args[0] || lc $args[0] ne '-answer') {
        return 1;
    }

    # set session type.
    $sess->{type} = 'AnswerQuestion';
    
    return 1;
    
}

# say command cancel.
sub cmd_say_100 {
    my ($event, $user, $channel, @args) = @_;
    
    # in ask mode, this command can't be used.
    if ($channel->{sess} && $channel->{sess}->session_type eq 'AskQuestion') {
        $channel->send_privmsg('You cannot speak while asking a question. You can only observe as two strangers discuss it.');
        return $event->cancel('omegle.command.0-say');
    }
    
    return 1;
}

$mod

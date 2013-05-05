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

sub init {

    # register question event.
    $mod->register_omegle_event(
        name        => 'question',
        description => 'a question was asked or will be answered',
        callback    => \&sess_question
    ) or return;
    
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
    
    return 1;   
}

# received question.
sub sess_question {
    my ($event, $sess, $question) = @_;
    $sess->{channel}->send_privmsg("Question: $question");
}

# TODO: spy events.

# start command handler.
sub cmd_start_0 {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $event->{sess};
    
    # we don't care about this.
    if (!defined $args[0] || lc $args[0] ne '-ask') {
        return 1;
    }

    # no question?
    if (scalar @args < 2) {
        $channel->send_privmsg('Please provide a question.');
        $event->{stop} = 1;
        return;
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

$mod

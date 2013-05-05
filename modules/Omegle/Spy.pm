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
    
    return 1;   
}

# received question.
sub sess_question {
    my ($event, $sess, $question) = @_;
    $sess->{channel}->send_privmsg("Question: $question");
}
# TODO: -question

$mod

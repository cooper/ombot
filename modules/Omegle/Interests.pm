# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic conversation module
package API::Module::Omegle::Interests;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name          => 'Omegle::Interests',
    version       => '1.0',
    description   => 'allows you to meet strangers with interests similar to yours',
    depends_bases => ['OmegleEvents', 'Commands'],
    depends_mods  => ['Omegle::Basic'],
    initialize  => \&init
);

sub init {

    # register common_interests event.
    $mod->register_omegle_event(
        name        => 'common_interests',
        description => 'interests shared with stranger received',
        callback    => \&sess_common_interests
    ) or return;
    
    # register handler for start command.
    $mod->register_command(
        command     => 'start',
        priority    => 0, # halfway between
        callback    => \&cmd_start_0,
        description => 'handles common interests for Omegle'
    ) or return;
    
    return 1;   
}

# received common interests.
sub sess_common_interests {
    my ($event, $sess, @interests) = @_;
    $sess->{channel}->send_privmsg('You and the stranger both like '.join(', ', @interests).q(.));
}

# start command handler.
sub cmd_start_0 {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $event->{sess};
    
    # we don't care about this.
    if (!defined $args[0] || lc $args[0] ne '-interests') {
        return 1;
    }
    
    # if no interests are provided.
    if (scalar @args < 2) {
        $channel->send_privmsg('You must supply one or more interests, separated by commas.');
        $event->{stop} = 1;
        return;
    }
    
    # separate by commands.
    my @interests = map { s/^(\s*)//; s/(\s*)$//; $_ } split(',', join(' ', @args[1..$#args]));
    print "interests: @interests\n";
    
    # set session type and interests.
    $sess->{type}   = 'CommonInterests';
    $sess->{topics} = \@interests;
    
    return 1;
}

$mod

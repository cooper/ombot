# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic conversation module
package API::Module::Omegle::CommonInterests;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'Omegle::CommonInterests',
    version     => '1.0',
    description => 'allows you to meet strangers with interests similar to yours',
    requires    => ['OmegleEvents', 'Commands'],
    initialize  => \&init
);

sub init {

    # register common_interests event.
    $mod->register_omegle_event(
        name        => 'common_interests',
        description => 'interests shared with stranger received',
        callback    => \&sess_common_interests
    ) or return;
    
    return 1;   
}

# received common interests.
sub sess_common_interests {
    my ($event, $sess, @interests) = @_;
    $sess->{channel}->send_privmsg('You and the stranger both like '.join(', ', @interests).q(.));
}

$mod

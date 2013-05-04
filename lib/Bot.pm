# Copyright (c) 2013 Matthew Barkdale, Mitchell Cooper
package Bot;

use warnings;
use strict;
use parent 'EventedObject';

# create a new bot instance.
sub new {
    return bless {}, shift;
}

# send a message if connected.
sub om_say {
    my ($bot, $channel, $message) = @_;
    my $sess = $channel->{preferred_session} || $channel->{session};
    
    # check if a stranger is present.
    if (!$sess || !$sess->connected) {
        $channel->send_privmsg('No stranger is connected.');
        return;
    }
    
    $channel->send_privmsg("You: $message");
    $sess->say($message);
    
}

1

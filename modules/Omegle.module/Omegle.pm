# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Provides an interface for connecting to Omegle.com
package API::Module::Omegle;

use warnings;
use strict;
use utf8;
use API::Module;

BEGIN {
    my $dir = "$main::Bin/../lib/net-async-omegle";
    
    # add Net::Async::Omegle submodule directory if needed.
    if (!($dir ~~ @INC)) {
        unshift @INC, $dir;
    }
}

our $mod = API::Module->new(
    name        => 'Omegle',
    version     => '1.0',
    description => 'provides an interface for connecting to Omegle.com',
    initialize  => \&init,
    void        => \&void
);

our $om;

# initialize.
sub init {

    # load Net::Async::Omegle.
    $mod->require_perl('Net::Async::Omegle') or return;

    # create Net::Async::Omegle object.
    $om = $main::om = Net::Async::Omegle->new();
    $main::loop->add($main::om);
    
    # fetch Omegle status information for the first time.
    $om->update;

    # load the OmegleEvents base submodule.
    $mod->load_submodule('EventsBase') or return;

    # register the OmegleEvents API::Module base.
    my $events_base = $mod->{api}->get_module('Omegle.EventsBase')  or return;
    $events_base->register_base('OmegleEvents') or return;

    # copy Bot methods.
    *Bot::om_say = *om_say;

    return 1;
}

# unload module.
sub void {

    $main::loop->remove($om);
    undef $main::om;
    undef $om;
    undef *Bot::om_say;
    
    return 1;
    
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

$mod

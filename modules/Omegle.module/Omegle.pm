# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Provides an interface for connecting to Omegle.com
package API::Module::Omegle;

use warnings;
use strict;
use utf8;
use API::Module;

use Net::Async::Omegle;

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

    # create Net::Async::Omegle object.
    $om = $main::om = Net::Async::Omegle->new();
    $main::loop->add($main::om);
    
    # fetch Omegle status information for the first time.
    $om->update;

    # load the OmegleEvents base submodule.
    $mod->load_submodule('EventsBase');

    # register the OmegleEvents API::Module base.
    my $events_base = $mod->{api}->get_module('Omegle.EventsBase') or return;
    $mod->{api}->register_base_module(OmegleEvents => $events_base) or return;

    return 1;
}

# unload module.
sub void {

    $main::loop->remove($main::om);
    undef $main::om;
    undef $om;

}

$mod

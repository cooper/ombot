# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic conversation module
package API::Module::Omegle::Basic;

use warnings;
use strict;
use utf8;
use API::Module;

use Net::Async::Omegle;

our $mod = API::Module->new(
    name        => 'Omegle::Basic',
    version     => '1.0',
    description => 'provides traditional Omegle chat functionality',
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
    my $events_base = $mod->{api}->get_module('Omegle::Basic.EventsBase') or return;
    $mod->{api}->register_base_module(OmegleEvents => $events_base) or return;

    # load Omegle event submodule.
    $mod->load_submodule('Events') or return;
    
    # load command submodule.
    $mod->load_submodule('Commands') or return;

    return 1;   
}

# unload module.
sub void {

    $main::loop->remove($main::om);
    undef $main::om;
    undef $om;

}

$mod

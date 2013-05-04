# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic conversation module
package API::Module::Omegle::Basic;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'Omegle::Basic',
    version     => '1.0',
    description => 'provides traditional Omegle chat functionality',
    initialize  => \&init
);

# initialize.
sub init {

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

$mod

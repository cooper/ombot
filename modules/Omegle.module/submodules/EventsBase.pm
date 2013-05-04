# Copyright (c) 2013 Matthew Barkdale, Mitchell Cooper 
# API::Module base for OmegleEvents
package API::Module::Omegle::EventsBase;

use warnings;
use strict;

use API::Module;

our $mod = API::Module->new(
    name        => 'EventsBase',
    version     => '1.0',
    description => 'API::Module base for registering Omegle event handlers',
    initialize  => sub { 1 }
);

# registers an Omegle event.
sub register_omegle_event {
    my ($mod, %opts) = @_;

    # make sure all required options are present.
    foreach my $what (qw|name description callback|) {
        next if exists $opts{$what};
        $opts{name} ||= 'unknown';
        $main::api->log2("module $$mod{name} didn't provide '$what' option for register_omegle_event()");
        return;
    }
    
    # make sure callback is code.
    if (ref $opts{callback} ne 'CODE') {
        $main::api->log2("module $$mod{name} didn't supply CODE for register_omegle_event()");
        return;
    }
    
    # unique callback name.
    my $cb_name = $mod->unique_callback('omegleEvent', $opts{name});

    $mod->{omegle_event_callbacks} ||= [];
   
    # register the event.
    $main::om->register_event($opts{name} => $opts{callback}, name => $cb_name);
    push @{$mod->{omegle_event_callbacks}}, [$opts{name}, $cb_name];
    
    $main::api->log2("module $$mod{name} registered '$opts{name}' omegle event");
    return 1;
    
}

# unload omegle event handlers.
sub _unload {
    my ($class, $mod) = @_;
    return 1 unless $mod->{omegle_event_callbacks};
    $main::om->delete_event(@$_) foreach @{$mod->{omegle_event_callbacks}};
    return 1;
}

$mod

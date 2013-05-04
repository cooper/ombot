# COPYRIGHT (c) 2013 Matthew Barkdale, Mitchell Cooper 
package API::Base::Commands;

use warnings;
use strict;

# registers a command.
sub register_command {
    my ($mod, %opts) = @_;

    # make sure all required options are present.
    foreach my $what (qw|command description callback|) {
        next if exists $opts{$what};
        $opts{command} ||= 'unknown';
        $main::api->log2("module $$mod{name} didn't provide '$what' option for register_command()");
        return;
    }
    
    # make sure callback is code.
    if (ref $opts{callback} ne 'CODE') {
        $main::api->log2("module $$mod{name} didn't supply CODE for register_command()");
        return;
    }
    
    # unique callback name.
    my $cb_name = $mod->unique_callback('command', $opts{command});

    $mod->{command_callbacks} ||= [];
   
    # register the event.
    my $event_name = q(command_).$opts{command};
    $main::bot->register_event($event_name => $opts{callback}, name => $cb_name, %opts);
    push @{$mod->{command_callbacks}}, [$event_name, $cb_name];
    
    $main::api->log2("module $$mod{name} registered '$opts{command}' command");
    return 1;
    
}

# unload command handlers.
sub _unload {
    my ($class, $mod) = @_;
    return 1 unless $mod->{command_callbacks};
    $main::bot->delete_event(@$_) foreach @{$mod->{command_callbacks}};
    return 1;
}

1

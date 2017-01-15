# COPYRIGHT (c) 2013 Matthew Barkdale, Mitchell Cooper 
package API::Base::Commands;

use warnings;
use strict;

# registers a command.
sub register_command {
    my ($mod, %opts) = @_;
    my $name = $mod->full_name;
    
    # make sure all required options are present.
    foreach my $what (qw|command description callback|) {
        next if exists $opts{$what};
        $opts{command} ||= 'unknown';
        $::api->log2("module $name didn't provide '$what' option for register_command()");
        return;
    }
    
    # make sure callback is code.
    if (ref $opts{callback} ne 'CODE') {
        $::api->log2("module $name didn't supply CODE for register_command()");
        return;
    }
    
    # unique callback name.
    my $cb_name = $mod->unique_callback('command', $opts{command});

    $mod->{command_callbacks} ||= [];
   
    # register the event.
    my $event_name = q(command_).$opts{command};
    $::bot->register_event($event_name => $opts{callback}, name => $cb_name, %opts);
    push @{$mod->{command_callbacks}}, [$event_name, $cb_name];
    
    $::api->log2("module $name registered '$opts{command}' command");
    return 1;
    
}

# unload command handlers.
sub _unload {
    my ($class, $mod) = @_;
    return 1 unless $mod->{command_callbacks};
    $::bot->delete_event(@$_) foreach @{$mod->{command_callbacks}};
    return 1;
}

1

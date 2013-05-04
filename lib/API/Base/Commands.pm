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
    my $cb_name = $mod->full_name.q(.command.).$opts{command};
    
    # make sure this command hasn't been registered already.
    if ($cb_name ~~ @{$mod->{command_callbacks}}) {
        $main::api->log2("module $$mod{name} attempted to register command '$opts{command}' multiple times");
        return;
    }
    
   
    # register the event.
    $main::bot->register_event('command_'.$opts{command} => $opts{callback});
    push @{$mod->{command_callbacks}}, $cb_name;
    
    $main::api->log2("module $$mod{name} registered '$opts{command}' command");
    return 1;
    
}

# unload command handlers.
sub _unload {
    my ($class, $mod) = @_;
    $main::bot->delete_event($_) foreach @{$mod->{command_callbacks}};
    return 1;
}

1

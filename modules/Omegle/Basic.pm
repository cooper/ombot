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
    requires    => ['OmegleEvents', 'Commands'],
    initialize  => \&init,
    after_load  => \&loaded
);

# initialize.
sub init {
    return 1;   
}

# module loaded.
sub loaded {

    # load Omegle event submodule.
    $mod->load_submodule('Events') or return;
    
    # load command submodule.
    $mod->load_submodule('Commands') or return;
    
    return 1;
    
}

$mod

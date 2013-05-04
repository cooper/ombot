# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Traditional Omegle commands
package API::Module::Omegle::Basic;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'Omegle::Basic',
    version     => '1.0',
    description => 'provides traditional Omegle chat functionality',
    depends     => ['Omegle'],
    initialize  => \&init
);

# initialize.
sub init {

    # load Omegle event submodule.
    $mod->load_submodule('Events') or return;
    
    # load command submodule.
    $mod->load_submodule('Commands') or return;

    return 1;   
}

$mod

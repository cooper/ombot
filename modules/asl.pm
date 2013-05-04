# Copyright (c) 2013
# ASL module
package API::Module::asl;

use warnings;
use strict;
use utf8;
use API::Module;

our $mod = API::Module->new(
    name        => 'asl',
    version     => '1.0',
    description => 'generates random age, sex, and location',
    #requires    => ['Commands'],
    initialize  => \&init
);

sub init {
    return 1;   
}

$mod

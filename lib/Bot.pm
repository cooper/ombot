# Copyright (c) 2013 Matthew Barkdale, Mitchell Cooper
package Bot;

use warnings;
use strict;
use parent 'Evented::Object';

# create a new bot instance.
sub new {
    return bless {}, shift;
}

1

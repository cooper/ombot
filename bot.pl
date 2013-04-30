#!/usr/bin/env perl

BEGIN {
    use FindBin qw($Bin);
    unshift(@INC, "$Bin/lib");
}

use strict;
use warnings;
use FindBin qw($Bin);

use IO::Async;
use IO::Async::Loop;
use IO::Async::Stream;
use IO::Socket::IP;

use Net::Async::Omegle;
use Config::JSON;

my ($mainLoop, $ircSocket, $asyncStream, $configFile, $config);

# Config file? Default to bot.conf unless otherwise told
$configFile = $ARGV[0] || 'bot.conf';

# Let's make a new Config::JSON based on config file
$config = Config::JSON->new($configFile);

# Initialization subroutine
sub bot_init {
    # Create socket
}

# Let's go
$mainLoop->run;

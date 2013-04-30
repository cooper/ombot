#!/usr/bin/env perl
# Omegle IRC bot by Matthew Barksdale 
# Version: 0.1-dev

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

my ($mainLoop, $configFile, $config);
my ($youSocket, $youStream, $omSocket, $omStream);

# Config file? Default to bot.conf unless otherwise told
$configFile = $ARGV[0] || 'bot.conf';

# Let's make a new Config::JSON based on config file
$config = Config::JSON->new($configFile);

# Initialization subroutine
sub bot_init {
    # Create loop
    $mainLoop = IO::Async::Loop->new;
    # Create sockets
    $youSocket = IO::Socket::IP->new(
        PeerAddr  => $config->get('host'),
        PeerPort  => $config->get('port'),
        LocalAddr => $config->get('bind'),
        Timeout   => 10
    );
    $omSocket = IO::Socket::IP->new(
        PeerAddr  => $config->get('host'),
        PeerPort  => $config->get('port'),
        LocalAddr => $config->get('bind'),
        Timeout   => 10
    );
    # Create streams

    # Send intros
    send_intro();
    # Let's go
    $mainLoop->run;
}

# Send data to IRC
sub irc_send
{
    my ($to, $data) = @_;
    if (lc $to eq 'you')
    {
        $to = $youStream;
    }
    else
    {
        $to = $omStream;
    }
    chomp $data;
    $to->write($data."\r\n");
}

sub send_intro
{
    # Send IRC intros
    my %nicks = ('you' => $config->get('you/nick'), 'om' => $config->get('ombot/nick'));
    foreach (qw/om you/)
    {
        irc_send($_, "NICK $nicks{$_}");
        irc_send($_, "USER omegle * * :Omegle IRC Bot");
    }
}

# Let's go
bot_init();

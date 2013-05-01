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
use feature qw(say switch);

use IO::Async;
use IO::Async::Loop;
use IO::Async::Stream;
use IO::Socket::IP;

use Net::Async::Omegle;
use Config::JSON;

my ($mainLoop, $configFile, $config);
my ($youSocket, $youStream, $omSocket, $omStream);
my $om;

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
    $youStream = IO::Async::Stream->new(
        handle => $youSocket,
        on_read => sub {
            my ($self, $buffref, $eof) = @_;
            while ($$buffref =~ s/^(.*)\n//)
            {
                irc_parse('you', $1);
            }
            return 0;
        },
    );
    $omStream = IO::Async::Stream->new(
        handle => $youSocket,
        on_read => sub {
            my ($self, $buffref, $eof) = @_;
            while ($$buffref =~ s/^(.*)\n//)
            {
                irc_parse('om', $1);
            }
            return 0;
        },
    );
    # Create Net::Async::Omegle object
    $om = Net::Async::Omegle->new(
        on_error => \&om_error,
        on_chat  => \&om_chat,
        on_type  => \&om_type,
        on_stoptype => \&om_stoptype,
        on_got_id => \&om_gotid,
        on_wantcaptcha => \&om_wantcaptcha,
        on_gotcaptcha => \&om_gotcaptcha,
        on_badcaptcha => \&om_badcaptcha);
    # Add to loop
    $mainLoop->add($youStream);
    $mainLoop->add($omStream);
    $mainLoop->add($om);
    # Send intros
    send_intro();
    # Let's go
    $mainLoop->run;
}

# Get stream by id
sub stream_by_id
{
    my $id = shift;
    return $youStream if lc($id) eq 'you';
    return $omStream if lc($id) eq 'om';
    return 0; # No match
}

# Send data to IRC
sub irc_send
{
    my ($to, $data) = @_;
    my $streamObj = stream_by_id($to);
    return if !$streamObj; # Bail, no match was found (???)
    chomp $data;
    $streamObj->write($data."\r\n");
    say "[$to] >> $data" if $config->get('debug');
}

# Send IRC intro
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

# Parse IRC
sub irc_parse
{
    my ($from, $data) = @_;
    my $streamObj = stream_by_id($from);
    return if !$streamObj; # Bail, no match was found (???)
    my @ex = split(' ', $data); # Space split
    irc_send($from, "PONG $ex[1]") if $ex[0] eq 'PING';
    say "[$from] << $data" if $config->get('debug');
}

# Bot say
sub om_say
{
    my $data = shift;
    my $chan = $config->get('channel');
    irc_send('om', "PRIVMSG $chan :$data");
}

# You say
sub you_say
{
    my $data = shift;
    my $chan = $config->get('channel');
    irc_send('you', "PRIVMSG $chan :$data");
}


# Let's go
bot_init();

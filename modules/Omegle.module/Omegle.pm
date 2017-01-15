# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Provides an interface for connecting to Omegle.com
package API::Module::Omegle;

use warnings;
use strict;
use utf8;
use API::Module;

BEGIN {
    my $dir = "$::Bin/../lib/net-async-omegle";

    # add Net::Async::Omegle submodule directory if needed.
    if (!($dir ~~ @INC)) {
        unshift @INC, $dir;
    }
}

our $mod = API::Module->new(
    name          => 'Omegle',
    version       => '1.0',
    description   => 'provides an interface for connecting to Omegle.com',
    depends_perl  => ['Net::Async::Omegle'],
    initialize    => \&init,
    void          => \&void
);

our $om;
our ($default_wpm, $wpm) = 100; # TODO: configurable.
our $wpm_delay = 0;

# initialize.
sub init {

    # create Net::Async::Omegle object.
    $om = $::om = Net::Async::Omegle->new();
    $::loop->add($::om);
    $::om->init;

    # load the OmegleEvents base submodule.
    $mod->load_submodule('EventsBase') or return;

    # register the OmegleEvents API::Module base.
    my $events_base = $mod->{api}->get_module('Omegle.EventsBase') or return;
    $events_base->register_base('OmegleEvents') or return;

    # copy Bot methods.
    *Bot::om_say       = *om_say;
    *Bot::om_type      = *om_type;
    *Bot::om_connected = *om_connected;
    *Bot::om_running   = *om_running;

    return 1;
}

# unload module.
sub void {

    $::loop->remove($om);
    undef $::om;
    undef $om;

    undef *Bot::om_say;
    undef *Bot::om_type;
    undef *Bot::om_connected;
    undef *Bot::om_running;

    return 1;

}

# send a message if connected.
sub om_say {
    my ($bot, $channel, $message) = @_;
    my $sess = $channel->{preferred_session} || $channel->{sess};

    # not connected.
    $bot->om_connected($channel) or return;

    # increase delay
    my $delay_all = \$wpm_delay;
    my $delay     = get_wpm_delay($message);
    $$delay_all  += $delay;

    # start typing
    $bot->om_type($channel) if $delay;

    # send the message after typing delay.
    my $timer = IO::Async::Timer::Countdown->new(
        delay     => $$delay_all,
        on_expire => sub {
            my $connected = $sess->connected;

            # upcoming messages -- type again.
            $bot->om_type($channel)
                if $delay && $$delay_all && $connected;

            $$delay_all -= $delay;
            $connected or return;

            $sess->say($message);
        }
    );

    $::loop->add($timer);
    $timer->start;
}

sub om_type {
    my ($bot, $channel) = @_;
    my $sess = $channel->{preferred_session} || $channel->{sess};

    # not connected.
    $bot->om_connected($channel) or return;

    $sess->type or return;
    $channel->send_privmsg('You are typing...');
}

# check if a stranger is connected.
# if not, send an error and return false.
sub om_connected {
    my ($bot, $channel) = @_;
    my $sess = $channel->{preferred_session} || $channel->{sess};

    # yep.
    return 1 if $sess && $sess->connected;

    # nope.
    $channel->send_privmsg('No stranger is connected.');
    return;

}

# check if a session is running.
# if not, send an error and return false.
sub om_running {
    my ($bot, $channel) = @_;
    my $sess = $channel->{preferred_session} || $channel->{sess};

    # yep.
    return 1 if $sess && $sess->running;

    # nope.
    $channel->send_privmsg('No session is currently running.');
    return;

}

sub wpm () { $wpm // $default_wpm }

sub wpm2delay {
    my ($wpm, $msg) = @_;
    return 0 if !$wpm;
    my $chardelay = 60 / ($wpm * 5);
    my $typedelay = $chardelay * length $msg;
    return $typedelay;
}

sub get_wpm_delay {
    my $msg = shift;
    return wpm2delay(wpm, $msg);
}

$mod

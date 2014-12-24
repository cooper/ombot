# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Provides an interface for connecting to Omegle.com
package API::Module::Omegle;

use warnings;
use strict;
use utf8;
use API::Module;

BEGIN {
    my $dir = "$main::Bin/../lib/net-async-omegle";
    
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

# initialize.
sub init {

    # create Net::Async::Omegle object.
    $om = $main::om = Net::Async::Omegle->new();
    $main::loop->add($main::om);
    
    # fetch Omegle status information for the first time.
    $om->update;

    # load the OmegleEvents base submodule.
    $mod->load_submodule('EventsBase') or return;

    # register the OmegleEvents API::Module base.
    my $events_base = $mod->{api}->get_module('Omegle.EventsBase') or return;
    $events_base->register_base('OmegleEvents') or return;

    # copy Bot methods.
    *Bot::om_say       = *om_say;
    *Bot::om_connected = *om_connected;
    *Bot::om_running   = *om_running;

    return 1;
}

# unload module.
sub void {

    $main::loop->remove($om);
    undef $main::om;
    undef $om;
    
    undef *Bot::om_say;
    undef *Bot::om_connected;
    undef *Bot::om_running;
    
    return 1;
    
}

# send a message if connected.
sub om_say {
    my ($bot, $channel, $message) = @_;
    my $sess = $channel->{preferred_session} || $channel->{sess};
    
    # not connected.
    $main::bot->om_connected($channel) or return;
    
    my $str = ::get_format(om_msg_you => { message => $message });
    $channel->send_privmsg($str);
    $sess->say($message);
    
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

our ($default_wpm, $wpm) = 60; # TODO: configurable.
our $wpm_delay = 0;

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

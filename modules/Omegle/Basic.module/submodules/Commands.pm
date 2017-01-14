# Copyright (c) 2013 Matthew Barksdale, Mitchell Cooper
# Basic Omegle conversation commands module
package API::Module::Omegle::Basic::Commands;

use warnings;
use strict;
use utf8;
use API::Module;
use IO::Async::Timer::Countdown;

our $mod = API::Module->new(
    name        => 'Commands',
    version     => '1.1',
    description => 'provides an IRC interface to basic Omegle functionality',
    requires    => ['Commands'],
    initialize  => \&init
);

# command handlers.
my %commands = (
    stop => {
        description => 'stops a running session',
        callback    => \&cmd_stop,
        name        => 'omegle.command.0-stop'
    },
    type => {
        description => 'sends a typing event',
        callback    => \&cmd_type,
        name        => 'omegle.command.0-type'
    },
    say => {
        description => 'sends a message',
        callback    => \&cmd_say,
        name        => 'omegle.command.0-say'
    },
    count => {
        description => 'displays the online user count',
        callback    => \&cmd_count,
        name        => 'omegle.command.0-count'
    },
    status => {
        description => 'displays current Omegle status',
        callback    => \&cmd_status,
        name        => 'omegle.command.0-status'
    },
    captcha => {
        description => 'submits a captcha response',
        callback    => \&cmd_captcha,
        name        => 'omegle.command.0-captcha'
    },
    setwpm => {
        description => 'set fake typing speed',
        callback    => \&cmd_setwpm,
        name        => 'omegle.command.0-setwpm'
    }
);

our ($default_wpm, $wpm) = 60;

sub init {

    # register commands.
    foreach (keys %commands) {
        $mod->register_command(command => $_, %{$commands{$_}}) or return;
    }

    # register 100 priority start.
    $mod->register_command(
        command     => 'start',
        priority    => 100,
        callback    => \&cmd_start_100,
        name        => 'omegle.command.100-start',
        description => 'checks if a session is already running'
    );

    # register -100 priority start.
    $mod->register_command(
        command     => 'start',
        priority    => -100,
        callback    => \&cmd_start_n100,
        name        => 'omegle.command.-100-start',
        description => 'starts an Omegle conversation'
    );

    return 1;
}

########################
### COMMAND HANDLERS ###
########################

# create and start a new session.
# this callback with 100 priority will be called before any extensions.
sub cmd_start_100 {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};

    # check if a session already is running in this channel.
    if ($sess && $sess->running) {
        $channel->send_privmsg('There is already a session in progress.');
        return $event->stop;
    }

    # no session is running. continue to execute any additional handlers.
    $event->{sess} = $main::om->new;
    return 1;

}

# create and start a new session.
# this callback with -100 priority will be called after any extensions.
sub cmd_start_n100 {
    my ($event, $user, $channel, @args) = @_;

    # create a new session if an earlier callback hasn't already.
    my $sess = $event->{sess} || $main::om->new;
    $channel->{sess} = $sess;
    $sess->{channel} = $channel;

    $sess->start;
}

# stop a session.
sub cmd_stop {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};

    # check if a session already is running in this channel.
    if (!$sess || !$sess->running) {
        $channel->send_privmsg('No session is currently running.');
        $event->stop;
        return;
    }

    # disconnect from Omegle.
    $sess->disconnect;
    $channel->send_privmsg('You have disconnected.');

}

# send a typing event.
sub cmd_type {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};

    # not connected.
    $main::bot->om_connected($channel) or return;

    $sess->type or return;
    $channel->send_privmsg('You are typing...');
}

# submit a captcha response.
sub cmd_captcha {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};

    # not connected.
    $main::bot->om_running($channel) or return;

    # server is not waiting for a captcha response.
    if (!$sess->waiting_for_captcha) {
        $channel->send_privmsg('No captcha requires submission.');
        return;
    }

    $channel->send_privmsg('Verifying...');
    $sess->submit_captcha(join ' ', @args);

}

# send a message.
sub cmd_say {
    my ($event, $user, $channel, @args) = @_;
    my $sess = $channel->{sess};

    # not connected.
    $main::bot->om_running($channel) or return;

    # determine the typing delay.
    # TODO: use the actual message substr'd.
    # connected check in om_say()
    my $delay_all = \$API::Module::Omegle::wpm_delay;
    my $message = join ' ', @args;
    my $delay   = API::Module::Omegle::get_wpm_delay($message);
    $$delay_all += $delay;
    cmd_type($event, $user, $channel) if $delay;

    # send the message after typing delay.
    my $timer = IO::Async::Timer::Countdown->new(
        delay     => $$delay_all,
        on_expire => sub {
            my $connected = $sess->connected;

            # upcoming messages -- type again.
            cmd_type($event, $user, $channel)
                if $delay && $$delay_all && $connected;

            $$delay_all -= $delay;
            $connected or return;
            $main::bot->om_say($channel, $message);
        }
    );

    $::loop->add($timer);
    $timer->start;
}

# display the user count.
sub cmd_count {
    my ($event, $user, $channel, @args) = @_;
    $channel->send_privmsg('There are currently '.$main::om->user_count.' users online.');
}

# display current status.
sub cmd_status {
    my ($event, $user, $channel, @args) = @_;
    my $om = $main::om;
    my $servers = join ', ', map /^(.*?)\..*$/, $om->servers;
    my @info = (
        'Servers online'    => $servers,
        'Current server'    => $om->last_server,
        'Ban status'        => $om->half_banned ? 'Forced unmonitored' : 'none',
        'Users online'      => ($om->user_count)[0]
    );
    while (@info) {
        my ($key, $val) = splice @info, 0, 2;
        my $str = ::get_format(om_status_pair => {
            key   => $key,
            value => $val
        });
        $channel->send_privmsg($str);
    }
}

sub cmd_setwpm {
    my ($event, $user, $channel, $set_wpm) = @_;
    my $wpm = \$API::Module::Omegle::wpm;

    # setting.
    if (defined $set_wpm) {
        if ($set_wpm =~ m/\D/) {
            $channel->send_privmsg('WPM must be an integer.');
            return;
        }
        $$wpm = $set_wpm;
        return $channel->send_privmsg('Fake typing disabled.') if !$set_wpm;
        return $channel->send_privmsg("Typing speed: $set_wpm wpm");
    }

    my $real_wpm = API::Module::Omegle::wpm();
    $channel->send_privmsg(
        $real_wpm                       ?
        "Typing speed: $real_wpm wpm"   :
        'Fake typing is not enabled.'
    );
}


$mod

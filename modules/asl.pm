# COPYRIGHT (c) 2013 JOAH
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
    requires    => ['Config', 'Commands'],
    initialize  => \&init
);

sub init {

    # register setasl command.
    $mod->register_command(
        command     => 'setasl',
        description => 'sets minimum and maximum ages for asl',
        callback    => \&cmd_setasl
    ) or return;

    # register asl command.
    $mod->register_command(
        command     => 'asl',
        description => 'sends a random age, sex, and location',
        callback    => \&cmd_asl
    ) or return;

    return 1;   
}

sub min () {
    defined $mod->{age_min}   ? $mod->{age_min}   :
    defined $mod->conf('min') ? $mod->conf('min') : 16;
}

sub max () {
    defined $mod->{age_max}   ? $mod->{age_max}   :
    defined $mod->conf('max') ? $mod->conf('max') : 26;
}

# setasl command.
sub cmd_setasl {
    my ($event, $user, $channel, $sess, @args) = @_;
    my $ages = join '', @args;
    my ($min, $max);
    
    # no args; display current values.
    if (!scalar @args) {
        ($min, $max) = (min, max);
        $channel->send_privmsg("Current ASL age range: $min to $max");
        return;
    }
    
    # age range must be in this format.
    if ($ages =~ m/^(\d+)\D+(\d+)$/) {
        $min = $1;
        $max = $2;
    }
    
    # format is invalid.
    else {
        $channel->send_privmsg('Invalid age range format.');
        return;
    }

    # format is valid.
    $mod->{age_min} = $min;
    $mod->{age_max} = $max;
    $channel->send_privmsg("Set ASL age range: $min to $max");

}

# asl command.
sub cmd_asl {
    my ($event, $user, $channel, $sess, @args) = @_;
    my $sex = $args[0]; # supplied sex.
    
    # fetch possibly values.
    my @ages  = (min..max);
    my @sexes = ('m', 'f');
    my @locs  = @{$mod->conf('locations') || ['ca', 'fl']};
    
    # choose random values.
    my $age   =  $ages[ rand @ages  ];
    my $loc   =  $locs[ rand @locs  ];
       $sex ||= $sexes[ rand @sexes ];
    
    # send the message to the stranger.
    $main::bot->om_say($channel, "$age $sex $loc");
    
}

$mod

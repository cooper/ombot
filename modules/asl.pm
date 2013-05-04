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
    requires    => ['Commands'],
    initialize  => \&init
);

sub init {

    # register setasl command.
    $mod->register_command(
        command     => 'setasl',
        description => 'sets minimum and maximum ages for asl',
        callback    => \&cmd_setasl
    ) or return;

    return 1;   
}

# setasl command.
sub cmd_setasl {
    my ($event, $user, $channel, $sess, @args) = @_;
    my $ages = join '', @args;
    my ($min, $max);
    
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

$mod

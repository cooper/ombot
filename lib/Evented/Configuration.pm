# Copyright (c) 2012, Mitchell Cooper
#
# Evented::Configuration:
# a configuration file parser and event-driven configuration class.
# Evented::Configuration is based on UICd::Configuration, the class of the UIC daemon.
# UICd's parser was based on juno5's parser, which evolved from juno4, juno3, and juno2.
# Early versions of Evented::Configuration were also found in several IRC bots, including
# foxy-java. Evented::Configuration provides several convenience fetching methods.
#
# Events:
#
# each time a configuration value changes, change:blocktype/blockname:key is fired. For unnamed
# blocks, the block type is omitted. For example, a block named 'chocolate' of type
# 'cookies' would fire the event 'change:cookies/chocolate:favorite' when its 'favorite' key
# is changed. An unnamed block of type 'fudge' would fire the event 'change:fudge:peanutbutter'
# when its 'peanutbutter' key is changed.
#
# If a value never existed, new values fire change events as well. If you want your
# listeners to respond to certain values even when the configuration is first loaded,
# simply add the listeners before calling parse_config(). If you wish for the opposite
# behavior, do the opposite: apply the handlers after calling parse_config().
#
# All events are fired with:
#    $old - first argument, the former value of this configuration key.
#    $new - second argument, the new value of this configuration key.
#
# The easiest way to attach configuration change events is with the on_change() method.
# It is also the safest way because event names could possibly change in the future.
# For example:
#
# $conf->on_change(['someBlockType', 'someBlockName'], 'key', sub {
#     my ($event, $old, $new) = @_;
#     ...
# });
#
# You can also add additional hash arguments for register_event() to the end.
#

package Evented::Configuration;

use warnings;
use strict;
use utf8;
use parent 'EventedObject';

our $VERSION = '3.2';

sub on  () { 1 }
sub off () { undef }

# create a new configuration instance.
sub new {
    my ($class, %opts) = (shift, @_);
    
    # if we still have no defined conffile, we must give up now.
    if (!defined $opts{conffile}) {
        $@ = 'no configuration file (conffile) option specified.';
        return;
    }
    
    # if 'hashref' is provided, use it.
    $opts{conf} = $opts{hashref} || $opts{conf} || {};
    
    # return the new configuration object.
    return bless \%opts, $class;
    
}

# parse the configuration file.
sub parse_config {
    my ($conf, $i, $block, $name, $key, $val, $config) = shift;
    open $config, '<', $conf->{conffile} or return;
    
    while (my $line = <$config>) {

        $i++;
        $line = trim($line);
        next unless $line;
        next if $line =~ m/^#/;

        # a block with a name.
        if ($line =~ m/^\[(.*?):(.*)\]$/) {
            $block = trim($1);
            $name  = trim($2);
        }

        # a nameless block.
        elsif ($line =~ m/^\[(.*)\]$/) {
            $block = 'section';
            $name  = trim($1);
        }

        # a key and value.
        elsif ($line =~ m/^(\s*)([\w:]*)(\s*)[:=]+(.*)$/ && defined $block) {
            $key = trim($2);
            $val = eval trim($4);
            die "Invalid value in $$conf{conffile} line $i: $@\n" if $@;
            
            # the value has changed, so send the event.
            if (!exists $conf->{conf}{$block}{$name}{$key} || $conf->{conf}{$block}{$name}{$key} ne $val) {
            
                # determine the name of the event.
                my $eblock = $block eq 'section' ? $name : $block.q(/).$name;
                my $event_name = "eventedConfiguration.change:$eblock:$key";
                
                # fetch the old value and set the new value.
                my $old = $conf->{conf}{$block}{$name}{$key};
                $conf->{conf}{$block}{$name}{$key} = $val;
                
                # fire the event.
                $conf->fire_event($event_name => $old, $val);
                
            }
            
        }

        # I don't know how to handle this.
        else {
            die "Invalid line $i of $$conf{conffile}\n";
        }

    }
    
    return 1;
}

# returns true if the block is found.
# supports unnamed blocks by get(block, key)
# supports   named blocks by get([block type, block name], key)
sub has_block {
    my ($conf, $block) = @_;
    $block = ['section', $block] if !ref $block || ref $block ne 'ARRAY';
    return 1 if $conf->{conf}{$block->[0]}{$block->[1]};
}

# returns a list of all the names of a block type.
# for example, names_of_block('listen') might return ('0.0.0.0', '127.0.0.1')
sub names_of_block {
    my ($conf, $blocktype) = @_;
    return keys %{$conf->{conf}{$blocktype}};
}

# returns a list of all the keys in a block.
# for example, keys_of_block('modules') would return an array of every module.
# accepts block type or [block type, block name] as well.
sub keys_of_block {
    my ($conf, $block, $blocktype, $section) = (shift, shift);
    $blocktype = (ref $block && ref $block eq 'ARRAY') ? $block->[0] : 'section';
    $section   = (ref $block && ref $block eq 'ARRAY') ? $block->[1] : $block;
    return my @a unless $conf->{conf}{$blocktype}{$section};
    return keys %{$conf->{conf}{$blocktype}{$section}};
}

# returns a list of all the values in a block.
# accepts block type or [block type, block name] as well.
sub values_of_block {
    my ($conf, $block, $blocktype, $section) = (shift, shift);
    $blocktype = (ref $block && ref $block eq 'ARRAY') ? $block->[0] : 'section';
    $section   = (ref $block && ref $block eq 'ARRAY') ? $block->[1] : $block;
    return my @a unless $conf->{conf}{$blocktype}{$section};
    return values %{$conf->{conf}{$blocktype}{$section}};
}

# returns the key:value hash of a block.
# accepts block type or [block type, block name] as well.
sub hash_of_block {
    my ($conf, $block, $blocktype, $section) = (shift, shift);
    $blocktype = (ref $block && ref $block eq 'ARRAY') ? $block->[0] : 'section';
    $section   = (ref $block && ref $block eq 'ARRAY') ? $block->[1] : $block;
    return my %h unless $conf->{conf}{$blocktype}{$section};
    return %{$conf->{conf}{$blocktype}{$section}};
}

# get a configuration value.
# supports unnamed blocks by get(block, key)
# supports   named blocks by get([block type, block name], key)
sub get {
    my ($conf, $block, $key) = @_;
    if (defined ref $block && ref $block eq 'ARRAY') {
        return $conf->{conf}{$block->[0]}{$block->[1]}{$key};
    }
    return $conf->{conf}{section}{$block}{$key};
}

# remove leading and trailing whitespace.
sub trim {
    my $string = shift;
    $string =~ s/\s+$//;
    $string =~ s/^\s+//;
    return $string;
}

# attach a configuration change listener.
# see notes at top of file for usage.
sub on_change {
    my ($conf, $block, $key, $code, %opts) = @_;
    my ($block_type, $block_name) = ('section', $block);
    
    # if $block is an array reference, it's (type, name).
    if (defined ref $block && ref $block eq 'ARRAY') {
        ($block_type, $block_name) = @$block;
    }
    
    # determine the name of the event.
    $block = $block_type eq 'section' ? $block_name : $block_type.q(/).$block_name;
    my $event_name = "eventedConfiguration.change:$block:$key";

    # register the event.
    return $conf->register_event($event_name => $code, %opts);
    
}

1

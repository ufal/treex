#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Tool::Memcached::Memcached;

my $action = shift @ARGV;

print STDERR "Action: $action\n";

if ( $action eq "start" ) {
    Treex::Tool::Memcached::Memcached::start_memcached(@ARGV);
}
elsif ( $action eq "load" ) {
    Treex::Tool::Memcached::Memcached::load_model(@ARGV);
}
elsif ( $action eq "stats" ) {
    Treex::Tool::Memcached::Memcached::print_stats();
}
elsif ( $action eq "stop" ) {
    Treex::Tool::Memcached::Memcached::stop_memcached();
} else {
    help();
}

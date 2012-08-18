#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Tool::Memcached::Memcached;
use File::Basename;
use Carp;
use List::Util qw(shuffle);

my ($checks, $model_file, $lemmas_file) = @ARGV;

my @lemmas = ();
open(my $fh, "<:encoding(utf-8)", $lemmas_file) or croak($! . ": " . $lemmas_file);
while ( <$fh> ) {
    chomp;
    push(@lemmas, $_);
}

my $lemma_count = scalar @lemmas;


my $memd = Treex::Tool::Memcached::Memcached::get_connection(basename($model_file));
my $hit = 0;
my $total = 0;
for my $it (0 .. $checks) {
    for my $i (shuffle (0 .. $lemma_count - 1)) {

        my $lemma = $lemmas[$i];
        
        my $contains = defined($memd->get(fix_key($lemma)));
        if ( ! $contains ) {
            print STDERR "Missing: " . $lemma . "\n";
        }
        $hit += $contains;
        $total++;
        
        if ( $total % 1000 == 0 ) {
            print STDERR $hit . "\t" . $total . "\n";
        }
    }
}

print $hit . "\t" . $total . "\n";


sub fix_key
{
    return Treex::Tool::Memcached::Memcached::fix_key(shift);
}

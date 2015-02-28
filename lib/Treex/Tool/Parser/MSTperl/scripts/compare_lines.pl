#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use autodie;

sub say {
    my $line = shift;
    print "$line\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

open my $file1, '<:utf8', $ARGV[0];
open my $file2, '<:utf8', $ARGV[1];

my $total = 0;
my $different = 0;
my $dif1 = 0;
my $dif2 = 0;
while (<$file1>) {
    my $line1 = $_;
    chomp $line1;
    my $line2 = <$file2>;
    chomp $line2;
    if ($line1) {
        $total++;
        if ($line1 ne $line2) {
            $different++;
	    my ($s11, $s12) = split /\t/, $line1;
	    my ($s21, $s22) = split /\t/, $line2;
	    if ($s11 ne $s21) {
		$dif1++;
	    }
	    if ($s12 ne $s22) {
		$dif2++;
	    }
        }
    }
}

my $same_perc = (1 - $different/$total) * 100;
my $same_perc1 = (1 - $dif1/$total) * 100;
my $same_perc2 = (1 - $dif2/$total) * 100;
say "SCORE: $different differing lines out of $total non-blank lines ($same_perc% same)";
say "SCORE 1: $dif1 differing 1st fields out of $total non-blank lines ($same_perc1% same)";
say "SCORE 2: $dif2 differing 2nd fields out of $total non-blank lines ($same_perc2% same)";

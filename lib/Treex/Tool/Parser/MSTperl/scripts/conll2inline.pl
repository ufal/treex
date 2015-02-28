#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub say {
    my $line = shift;
    print "$line\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my @sentence;
while (<>) {
    chomp;
    if ($_) {
	my $attributes = $_;
	$attributes =~ s/\t/ /g;
	push @sentence, $attributes;
    } else {
	print join "\t", @sentence;
	print "\n";
	@sentence = ();
    }
}
if (@sentence) {
    print join "\t", @sentence;
}

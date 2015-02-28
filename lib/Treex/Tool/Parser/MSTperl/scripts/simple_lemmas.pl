#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

use Treex::Tool::Lexicon::CS;

my $lemmaFieldIndex = 2;

open my $file, '<:utf8', $ARGV[0] or die 'cannot open input file';
while (<$file>) {
    chomp;
    if ($_) {
	my @fields = split /\t/;
	$fields[$lemmaFieldIndex] = Treex::Tool::Lexicon::CS::truncate_lemma ($fields[$lemmaFieldIndex], 1);
	print join "\t", @fields;
	print "\n";
    } else {
	print "\n";
    }
}
close $file;
print STDERR "Done.\n";

sub get_simple_lemma {
    my $lemma = shift;

    $lemma =~ s/-[0-9]+$//;
    #$lemma =~ s/(`|_[;:,^]).+$//;
    #$lemma =~ s/(-|`|_[;:,^]).+$//;

    return $lemma;
}

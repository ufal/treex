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

my %sentences;

while (<>) {
    chomp;
    my $sentence = $_;
    my @nodes = split /\t/;
    my $sent_length = scalar(@nodes);
    $sentences{$sentence} = $sent_length;
}

# ascending length
#my @sorted_sentences = sort {$sentences{$a} <=> $sentences{$b}} keys %sentences;

# descending length
my @sorted_sentences = sort {$sentences{$b} <=> $sentences{$a}} keys %sentences;

foreach my $sentence (@sorted_sentences) {
    say $sentence;
}

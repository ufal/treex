package Treex::Tool::NamedEnt::Features::Context;

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::NamedEnt::Features::Context - Package for extracting
named entity hintwords

=head1 SYNOPSIS

  use Treex::Tool::NamedEnt::Features::Context;

  $hintwords = get_hintwords($position, \@sentences);

  $surname_hintlist = $hintwords->{ps};

    # surname hintlist je hashref kde klíč => lemma, value => MI (mezi lemmatem a ps (typem))

  print join "\n",
      map {  }

  

  for $hintword (@hintwords)
      $hintCounts{$hintword}++;
  }

=head1 DESCRIPTION

This package exports method C<get_hintword> as described
above. It is used to extract hintwords for each named entity type.

=head1 AUTHOR

Jindra Helcl <jindra.helcl@gmail.com>, Petr Jankovský
<jankovskyp@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


use strict;
use warnings;

use Data::Dumper;

use Exporter 'import';
our @EXPORT = qw/get_hintwords/;

sub get_hintwords {
    my ($position, $sentences_ref) = @_;
    my @sentences = @$sentences_ref;

    log_error("Position must not be equal to 0") and return undef if $position == 0;

    my %hintCounts;
    my %lemmaCounts;
    my %typeCounts;

    my $totalEntityCount = 0;
    my $totalWordCount = 0;

    for my $sentence (@sentences) {

        my @words = @{$sentence->{words}};
        my @namedents = @{$sentence->{namedents}};
        my @lemmas = @{$sentence->{lemmas}};

        $totalWordCount += scalar(@words);
        

        for my $ne (@namedents) {

            if ($position > 0 ) {
                my $spos = $ne->{end} + $position;
            
                if ($spos > scalar(@words)) {
                    $hintCounts{$ne->{type}}{'<s_end>'}++;
                    $lemmaCounts{'<s_end>'}++;
                } else {
                    $hintCounts{$ne->{type}}{$lemmas[$spos-1]}++;
                    $lemmaCounts{$lemmas[$spos-1]}++;
                }

            } else {    
                my $spos = $ne->{start} + $position;

                if ($spos <= 0) {
                    $hintCounts{$ne->{type}}{'<s_beg>'}++;
                    $lemmaCounts{'<s_beg>'}++;
                } else {
#                    print STDERR "pozice entity: " . $ne->{start} . "   pozice lemmatu: " . $spos . "   pocet prvku v poli lemmat: " . scalar(@lemmas)  . "\n";
#                   print STDERR Dumper($sentence) and die if !defined($lemmas[$spos]);
#                  print STDERR Dumper($sentence) and print "\n\nlemma[0]: " . $lemmas[0] . "  namedent[0]: " . $namedents[0]->{type} . " " . $namedents[0]->{start} . "  namedent[1]: " . $namedents[1]->{type} . " " . $namedents[1]->{start} . "\n\n" and die if $ne->{start} == 1;
                    $hintCounts{$ne->{type}}{$lemmas[$spos-1]}++;
                    $lemmaCounts{$lemmas[$spos-1]}++;
                }

            }
            $typeCounts{$ne->{type}}++;
            $totalEntityCount++;

        }

    }

    my %typeProb;
    my %lemmaProb;

    for my $type (keys %typeCounts) {
        $typeProb{$type} = $typeCounts{$type} / $totalEntityCount;
    }

    for my $lemma (keys %lemmaCounts) {
        $lemmaProb{$lemma} = $lemmaCounts{$lemma} / $totalWordCount;
    }

    my %typeLemmaProb;

    for my $type (keys %hintCounts) {
        for my $lemma (keys %{$hintCounts{$type}}) {
            $typeLemmaProb{$type}{$lemma} = $hintCounts{$type}{$lemma} / $totalEntityCount;
        }
    }

    my %PMI;

    for my $type (keys %hintCounts) {
        for my $lemma (keys %{$hintCounts{$type}}) {
            my $pmi = log($typeLemmaProb{$type}{$lemma} / ($typeProb{$type}*$lemmaProb{$lemma}));
            $PMI{$type}{$pmi}=$lemma;
        }
    }

    return \%PMI;
}


1;

#!/usr/bin/env perl

=pod

=encoding utf-8

=head1 NAME

Features.pl - Feature extraction for SysNERV SVM model

=head1 SYNOPSIS

B<./Features.pl> I<DATA_PLAIN> I<DATA_ANOT> [--model=<C<oneword>|C<twoword>|C<threeword>>]

B<./Features.pl> I<DATA_PLAIN> I<DATA_ANOT> --model=C<container> [threshold=I<THRESHOLD>]

=head1 DESCRIPTION

This script generates feature vectors for SysNERV from two input
files, C<DATA_PLAIN> and C<DATA_ANOT>. The first of them must be in
format C<form/lemma/tag>, one sentence per line, tokens separated by
spaces. The second file is in annotation format described in the
technical report, also one sentence per line. The lines of those files
are aligned.

=head1 OPTIONS

=over 4

=item B<--model>

Specifies the model to be prepared. Valid values are so far:
C<oneword>, C<twoword>, C<threeword> and C<container>.

=item B<--threshold>=I<THRESHOLD>

The threshold for container pattern maximum length. Defaults to infinity.

=back

=head1 AUTHOR

Jindra Helcl <jindra.helcl@gmail.com>, Petr Jankovský <jankovskyp@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Data::Dumper;

use Treex::Tool::NamedEnt::Features::Oneword;
use Treex::Tool::NamedEnt::Features::Twoword;
use Treex::Tool::NamedEnt::Features::Threeword;
use Treex::Tool::NamedEnt::Features::Containers;
use Treex::Tool::NamedEnt::Features::Common qw/get_class_number $FALLBACK_TAG $FALLBACK_LEMMA/;

use Getopt::Long;
use Pod::Usage;

my $model = "oneword";
my $threshold = 0;

GetOptions('model=s' => \$model,
	   'threshold=i' => \$threshold);

my $data = shift;
my $dataNer = shift;

pod2usage if !defined $dataNer;

# Struktura: seznam vet. veta={formy, lemmata, tagy, onewords, twowords, threewords}
#            onewords, twowords, threewords=seznam: (index, typ)
#            * indexy form, lemmat, tagu si odpovidaji a odpovidaji i indexum urcenym v seznamech entit
my @sentences;

open DATA, $data or die "Cannot open DATA file $data";
open DATANER, $dataNer or die "Cannot open DATA_NER file $dataNer";

my $noanot;

while (<DATA>) {
    chomp;

    my $anotated;
    my @namedents;

    if (!defined $noanot && !eof DATANER) {
        $anotated = <DATANER>;
        chomp $anotated;
        @namedents = parse_anot($anotated);

    } elsif (!defined $noanot) {
        #        print "No NER data after $.th line in the input\n";
        $noanot = 1;
    }

    my %sentence;
    my (@words, @lemmas, @tags);

    # parse plain sentence:

    my @nodes = split /\s+/;

    for my $node (@nodes) {
        my ($form, $lemma, $tag) = split /\//, $node, 3;
        die "Wrong format of tokens in plain format ($node)" if !defined $tag;

        push @words, $form;
        push @lemmas, $lemma;
        push @tags, $tag;

    }

    $sentence{words} = \@words;
    $sentence{lemmas} = \@lemmas;
    $sentence{tags} = \@tags;

    $sentence{namedents} = [];
    push @{$sentence{namedents}}, @namedents unless $noanot;

    push @sentences, \%sentence;
}


close DATA;
close DATANER;

my %patternCounts;

for my $sentence (@sentences) {

    my @words = @{$sentence->{words}};
    my @lemmas = @{$sentence->{lemmas}};
    my @tags = @{$sentence->{tags}};
    my @namedents = @{$sentence->{namedents}};

    if ($model eq 'container') {
	my @patterns = get_container_patterns($sentence, $threshold);
	$patternCounts{$_->{pattern}}{$_->{label}}++ for @patterns;
	next;
    }

    for my $i (0 .. $#words) {

        my %args;

        $args{'act_form'} = $words[$i];
        $args{'act_lemma'} = $lemmas[$i];
        $args{'act_tag'} = $tags[$i];

        $args{'prev_lemma'} = $i > 0 ? $lemmas[$i - 1] : $FALLBACK_LEMMA;
        $args{'prev_tag'} = $i > 0 ? $tags[$i - 1] : $FALLBACK_TAG;
        $args{'prev_form'} = $i > 0 ? $words[$i - 1] : $FALLBACK_LEMMA;

        $args{'pprev_tag'} = $i > 1 ? $tags[$i - 2] : $FALLBACK_TAG;
        $args{'pprev_lemma'} = $i > 1 ? $lemmas[$i - 2] : $FALLBACK_LEMMA;
        $args{'pprev_form'} = $i > 1 ? $words[$i - 2] : $FALLBACK_LEMMA;

        $args{'next_lemma'} = $i < $#words ? $lemmas[$i + 1] : $FALLBACK_LEMMA;
        $args{'next_form'} = $i < $#words ? $words[$i + 1] : $FALLBACK_LEMMA;
        $args{'next_tags'} = $i < $#words ? $tags[$i + 1] : $FALLBACK_TAG;


        # Urceni labelu pro kazdy model
        my ($onewordRef, $twowordRef, $threewordRef) = (-1,-1,-1);

        for my $ne (@namedents) {
            my $type = get_class_number($ne->{type});

            warn("Unknown class: " . $ne->{type}) and next if !defined $type;

            # Konci entita na teto pozici?
            if ( $ne->{end} == $i+1 ) {

                my $start = $ne->{start};

                $onewordRef = $type if $start == $i+1;
                $twowordRef = $type if $start == $i;
                $threewordRef = $type if $start == $i-1;
            }
        }

        my @features;

        if ($model eq 'oneword') {
            @features = extract_oneword_features( %args );
            push @features, $onewordRef;

        } elsif ($model eq 'twoword' && $i > 0) {
            @features = extract_twoword_features( %args );
            push @features, $twowordRef;

        } elsif ($model eq 'threeword' && $i > 1) {
            @features = extract_threeword_features( %args );
            push @features, $threewordRef;
        } else {
            next;
        }

        print join ",", @features;
        print "\n";
    }
}

if($model eq 'container') {
    for my $pattern (keys %patternCounts) {
	for my $label (keys %{$patternCounts{$pattern}} ) {
	    print "$pattern\t$label\t" . $patternCounts{$pattern}{$label} . "\n";
	}
    }
}

sub parse_anot {
    my $text_unprocessed = shift;

    # preprocessing

    my $text = $text_unprocessed;
    $text =~ s/\s?<\s?/ < /g;
    $text =~ s/\s?>\s?/ > /g;
    $text =~ s/\s+/ /g;

    my $effective_pos = 0;
    my $level = 0;

    # chci vratit pozice zacatku a koncu pojmenovanych entit a jejich typy (pozice = #slovo)

    my @tokens = split /\s+/, $text;
    my @entities_active;        # zasobnik
    my @entities;

    my $skip = 0;

    for my $i (0..$#tokens) {
        if ( $skip == 1) {
            $skip = 0;
            next;
        }

        my $current_token = $tokens[$i];

        if ($current_token =~ /</ ) {
            $level++;

            my $type = $tokens[$i+1];
            die "Undefined type" if !defined $type;
            die "Illeggal type" if $type =~ /[<>]/;

            push @entities_active, {type=>$type, start=>$effective_pos, end=>undef};
            $skip = 1;          # skip type definition
        } elsif ($current_token =~ />/) {
            $level--;
            die "Went under level 0" if $level < 0;

            my $entity = pop @entities_active;
            die "No entity in active stack" if !defined $entity;

            $entity->{end} = $effective_pos - 1;
            push @entities, $entity;
        } else {
            $effective_pos++;
        }
    }

    die "Did not end at level 0" if $level != 0;
    return @entities;
}

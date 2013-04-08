#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

use Treex::Tool::NamedEnt::Features::Oneword;
use Treex::Tool::NamedEnt::Features::Twoword;
use Treex::Tool::NamedEnt::Features::Threeword;
use Treex::Tool::NamedEnt::Features::Common qw/get_class_number $FALLBACK_TAG $FALLBACK_LEMMA/;

use Getopt::Long;

=pod

=head1 NAME

Features.pl - Feature extraction for SysNERV SVM model

=head1 SYNOPSIS

./Features.pl <neco>

=head1 DESCRIPTION

tenle skript vygeneruje feature vektory za pouziti nejaky ty tovarnicky ze dvou souboru:
2 soubory, jedna veta na radku, vety na stejnych radcich si odpovidaji. 1 soubor ve formatu form/lemma/tag, druhy ve formatu
s oanotovanymi pojmenovanymi entitami. Prvni soubor muze byt delsi, pak se predpoklada, ze named entities v techto additional
datech nejsou (data od Honzy Maska)

=cut

my $model = "oneword";
GetOptions('model=s' => \$model);

my ( $data, $dataNer ) = @ARGV;

die "Usage ./Features.pl DATA DATA_NER" if !defined $data or !defined $dataNer;


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
        die "Wrong format of tokens in plain format" if !defined $tag;

        push @words, $form;
        push @lemmas, $lemma;
        push @tags, $tag;

    }

    $sentence{words} = \@words;
    $sentence{lemmas} = \@lemmas;
    $sentence{tags} = \@tags;
    $sentence{namedents} = \@namedents unless $noanot;

    push @sentences, \%sentence;
}


close DATA;
close DATANER;


for my $sentence (@sentences) {

    my @words = @{$sentence->{words}};
    my @lemmas = @{$sentence->{lemmas}};
    my @tags = @{$sentence->{tags}};

    for my $i (0 .. $#words) {

        my %args;
        $args{'act_form'} = $words[$i];
        $args{'act_lemma'} = $lemmas[$i];
        $args{'act_tag'} = $tags[$i];

        $args{'prev_lema'} = $i > 0 ? $lemmas[$i - 1] : $FALLBACK_LEMMA;
        $args{'prev_tag'} = $i > 0 ? $tags[$i - 1] : $FALLBACK_TAG;
        $args{'prev_form'} = $i > 0 ? $words[$i - 1] : $FALLBACK_LEMMA;

        $args{'pprev_tag'} = $i > 1 ? $tags[$i - 2] : $FALLBACK_TAG;
        $args{'pprev_lemma'} = $i > 1 ? $lemmas[$i - 2] : $FALLBACK_LEMMA;
        $args{'pprev_form'} = $i > 1 ? $words[$i - 2] : $FALLBACK_LEMMA;

        $args{'next_lemma'} = $i < $#words ? $lemmas[$i + 1] : $FALLBACK_LEMMA;
        $args{'next_form'} = $i < $#words ? $words[$i + 1] : $FALLBACK_LEMMA;
        $args{'next_tags'} = $i < $#words ? $tags[$i + 1] : $FALLBACK_TAG;


        my @features;
        
        if ($model eq 'oneword') {
            @features = Treex::Tool::NamedEnt::Features::Oneword::extract(act_form => $args{'act_form'},
                                                                             act_lemma => $args{'act_lemma'},
                                                                             act_tag => $args{'act_tag'},
                                                                             prev_lemma => $args{'plemma'},
                                                                             prev_tag => $args{'ptag'},
                                                                             pprev_tag => $args{'pptag'},
                                                                             next_lemma => $args{'nlemma'});
	        my $reference = -1;
        } elsif($model eq 'twoword') {

        } elsif($model eq 'threeword') {

        }


	if (defined $sentence->{namedents}) {
	    for my $ne (@{$sentence->{namedents}}) {
		if ($ne->{start} == $i+1 && $ne->{end} == $i+1 && $model eq 'oneword') {
		    $reference = get_class_number($ne->{type});
                    if (!defined $reference) {
                        warn ("Unknown class: ". $ne->{type});
                        $reference = -1;
                    }
		}
        if ($ne->{start} == $i && $ne->{end} == $i+1 && $model  eq 'twoword') {

	    }
        if ($ne->{start} == $i && $ne->{end} == $i+2 && $model eq 'threeword') {

        }
	}

        print join ",", @features, $reference;
        print "\n";
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

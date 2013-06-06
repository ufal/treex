package Treex::Tool::NamedEnt::Features::Oneword;

use strict;
use warnings;

use Treex::Tool::NamedEnt::Features::Common qw/:oneword/;
use Treex::Tool::Lexicon::CS;

use Exporter 'import';
our @EXPORT = qw/ extract_oneword_features /;

sub extract_oneword_features {
    return extract(@_);
}

sub extract {
    my %args = @_;

    my ($form, $lemma, $tag) = @args{qw/act_form act_lemma act_tag/};
    my ($plemma, $ptag)      = @args{qw/prev_lemma prev_tag/};
    my $pptag                = $args{pprev_tag};
    my $nlemma               = $args{next_lemma};

    my @prev_namedents       = @{$args{namedents}};

    my $pos = substr $tag, 0, 1;
    my $bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($lemma);
    my $pbare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($plemma);
    my $nbare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($plemma);

    my @features;

    push @features, tag_features($_) for ($pptag, $ptag, $tag);
    push @features, is_tabu_pos($pos);

    push @features, map {Treex::Tool::Lexicon::CS::get_term_types($lemma) =~ /$_/ ? 1 : 0}
        qw /Y S E G K R m H U L j g c y b u w p z o/;


    # Orthographic features
    push @features, ( $bare_lemma =~ /^[[:upper:]]/ )                                ? 1 : 0;
    push @features, ( $bare_lemma =~ /^[[:upper:]]+$/ )                              ? 1 : 0; # all upper-case
    push @features, ( $bare_lemma =~ /^([01]?[0-9]|2[0-3])[.:][0-5][0-9]([ap]m)?$/ ) ? 1 : 0; # time
    push @features, ( $bare_lemma =~ /ová$/ )                                        ? 1 : 0;

    push @features, ( is_year_number($bare_lemma) )                                  ? 1 : 0;

    # Form
    push @features, ( $form =~ /^[[:upper:]]/ ) ? 1 : 0;

    # Built-in lists
    for my $list ( get_built_list_names() ) {
        push @features, ( is_listed_entity($list, $bare_lemma) ? 1 : 0 );
    }

    for my $list ( get_built_list_names() ) {
        push @features, ( is_listed_entity($list, $form) ? 1 : 0 );
    }



    # Previous lemma
    my $plemma_term_types = Treex::Tool::Lexicon::CS::get_term_types($plemma);

    push @features, ( $plemma_term_types =~ /Y/ )               ? 1 : 0;
    push @features, ( is_listed_entity('names', $pbare_lemma )) ? 1 : 0;
    push @features, ( is_listed_entity('months', $plemma))      ? 1 : 0;
    push @features, ( $pbare_lemma eq '/')                      ? 1 : 0;
    push @features, ( $pbare_lemma eq '.')                      ? 1 : 0;
    push @features, ( is_month_number($plemma) )                ? 1 : 0;


    my $nlemma_term_types = Treex::Tool::Lexicon::CS::get_term_types($nlemma);

    # Next lemma
    push @features, ( $nlemma_term_types =~ /S/ )                 ? 1 : 0;
    push @features, ( is_listed_entity('surnames', $nbare_lemma)) ? 1 : 0;
    push @features, ( is_listed_entity('objects', $nbare_lemma))  ? 1 : 0;
    push @features, ( $nbare_lemma eq '/' )                       ? 1 : 0;
    push @features, ( $nbare_lemma eq '.' )                       ? 1 : 0;
    push @features, ( is_year_number($nbare_lemma))               ? 1 : 0;

    push @features, context_features($plemma, $nlemma);

    return @features;
}

1;

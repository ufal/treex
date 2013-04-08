package Treex::Tool::NamedEnt::Features::Threeword;

use strict;
use warnings;

use Treex::Tool::NamedEnt::Features::Common qw/:threeword/;
use Treex::Tool::Lexicon::CS;

use Exporter 'import';
our @EXPORT = qw/ extract_threeword_features /;

sub extract_threeword_features {
    return extract(@_);
}

sub extract {
    my %args = @_;

    my ($first_lemma, $first_form) = @args{qw/pprev_lemma pprev_form/};
    my ($second_lemma, $second_form) = @args{qw/prev_lemma prev_form/};
    my ($third_lemma, $third_form) = @args{qw/act_lemma act_form/};
    my ($first_tag, $second_tag, $third_tag) = @args{qw/pprev_tag prev_tag act_tag/};

    my $first_bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($first_lemma);
    my $second_bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($second_lemma);
    my $third_bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($third_lemma);
    
#    my $joint_lemma = $first_lemma." ".$second_lemma." ".$third_lemma;
    my $form = $first_form." ".$second_form." ".$third_form;
    my $bare_lemma = $first_bare_lemma." ".$second_bare_lemma." ".$third_bare_lemma;
    
    my @features;

    # Build-in lists
#    push @features, ( _is_city($first_lemma, $second_lemma, $third_lemma) ) ? 1 : 0;
#    push @features, ( _is_country($first_lemma, $second_lemma, $third_lemma) ) ? 1 : 0;
    push @features, ( is_listed_entity("clubs", $first_bare_lemma) );
    push @features, ( is_listed_entity("clubs", $second_bare_lemma) );
    push @features, ( is_listed_entity("clubs", $third_bare_lemma) );

    # Orthographic features
    push @features, ( $second_bare_lemma eq '-' )       ? 1 : 0;
    push @features, ( $second_bare_lemma eq 'a' )       ? 1 : 0;
    push @features, ( $second_bare_lemma eq 'v' )       ? 1 : 0;
    
    return @features;
}

1;

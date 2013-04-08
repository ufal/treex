package Treex::Tool::NamedEnt::Features::Twoword;

use strict;
use warnings;

use Treex::Tool::NamedEnt::Features::Common qw/:twoword/;
use Treex::Tool::Lexicon::CS;

use Exporter 'import';
our @EXPORT = qw/ extract_twoword_features /;

sub extract_twoword_features {
    return extract(@_);
}

sub extract {
    my %args = @_;

    my ($first_lemma, $first_form) = @args{qw/prev_lemma prev_form/};
    my ($second_lemma, $second_form) = @args{qw/act_lemma act_form/};
    my ($ptag, $first_tag, $second_tag) = @args{qw/pprev_tag prev_tag act_tag/};

    my $first_bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($first_lemma);
    my $second_bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($second_lemma);
#    my $joint_lemma = $first_lemma." ".$second_lemma;
    my $bare_lemma = $first_bare_lemma." ".$second_bare_lemma;
#    my $ppos = substr $ptag, 0, 1;
    my $first_pos = substr $first_tag, 0, 1;
    my $second_pos = substr $second_tag, 0, 1;

    my @features;

    push @features, tag_features($_) for ($ptag, $first_tag, $second_tag);

    push @features, is_tabu_pos($first_pos);
    push @features, is_tabu_pos($second_pos);

    # Build-in lists
#    push @features, ( _is_city($first_lemma, $second_lemma) )       ? 1 : 0;
#    push @features, ( _is_city($first_lemma) )                      ? 1 : 0;
#    push @features, ( _is_city($second_lemma) )                     ? 1 : 0;
    push @features, ( is_listed_entity("city_parts", $bare_lemma) );
    push @features, ( is_listed_entity("streets", $bare_lemma) );
    push @features, ( is_listed_entity("names", $first_bare_lemma) );
    push @features, ( is_listed_entity("names", $second_bare_lemma) );
    push @features, ( is_listed_entity("surnames", $first_bare_lemma) );
    push @features, ( is_listed_entity("surnames", $second_bare_lemma) );
    push @features, ( is_listed_entity("objects", $first_bare_lemma) );
    push @features, ( is_listed_entity("objects", $second_bare_lemma) );
    push @features, ( is_listed_entity("institutions", $first_bare_lemma) );
    push @features, ( is_listed_entity("institutions", $second_bare_lemma) );
    push @features, ( is_listed_entity("clubs", lc $first_bare_lemma) );
    push @features, ( is_listed_entity("clubs", lc $second_bare_lemma) );
    push @features, ( is_listed_entity("months", $first_bare_lemma) );   
    push @features, ( is_listed_entity("surnames", $second_bare_lemma) );
#    push @features, ( _is_country($first_lemma, $second_lemma) )    ? 1 : 0;

    # Orthographic features
    push @features, ( $second_bare_lemma eq '.' )           ? 1 : 0;
    push @features, ( $second_bare_lemma eq '/' )           ? 1 : 0;
    push @features, ( $second_bare_lemma eq ')' )           ? 1 : 0;
    push @features, ( $second_bare_lemma eq '(' )           ? 1 : 0;
    push @features, ( $second_bare_lemma eq '%' )           ? 1 : 0;
    push @features, ( $second_bare_lemma eq ':' )           ? 1 : 0;
    push @features, ( $second_bare_lemma eq ',' )           ? 1 : 0;
#    push @features, ( _is_day_number($first_form) )         ? 1 : 0;
#    push @features, ( _is_month_number($first_form) )       ? 1 : 0;
    push @features, ( $first_lemma =~ /^[[:upper:]]/ )      ? 1 : 0;
    push @features, ( $second_lemma =~ /^[[:upper:]]/ )     ? 1 : 0;
    push @features, ( $first_form =~ /^[[:upper:]]/ )       ? 1 : 0;
    push @features, ( $second_form =~ /^[[:upper:]]/ )      ? 1 : 0;
    push @features, ( $first_form =~ /^[[:upper:]]$/ && $second_form eq '.') ? 1 : 0;

    foreach my $lemma ($first_lemma, $second_lemma) {
        push @features, map{Treex::Tool::Lexicon::CS::get_term_types($lemma) =~ /$_/ ? 1 : 0}
            qw/Y S E G K R m H U L j g c y b u w p z o/;
    }

    # Previous lemma
    my $prev_lemma = $args{'prev_lemma'};
    my $prev_bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($prev_lemma);
    push @features, ( $prev_bare_lemma eq '.' ) ? 1 : 0;
    push @features, ( $prev_bare_lemma eq '/' ) ? 1 : 0;

    # Next lemma
    my $next_lemma = $args{'next_lemma'};
    my $next_bare_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($next_lemma);
#    push @features, ( _is_year_number($next_bare_lemma) ) ? 1 : 0;

    return @features;
}

1;

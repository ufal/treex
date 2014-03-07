package Treex::Block::SemevalABSA::Coord;
use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/ uniq /;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @ands = grep { $_->afun eq 'Coord' && $_->lemma eq 'and' } $atree->get_descendants;

    for my $and ( @ands ) {
        my @candidates = grep { $self->is_aspect_candidate( $_ ) } $and->get_children;
        next if ! @candidates;
        next if scalar uniq(map { $_->tag } @candidates) > 1; # aspect candidates with non-matching tags
        my $tag = $candidates[0]->tag;
        my $total = $self->combine_polarities( map { $self->get_aspect_candidate_polarities( $_ ) } @candidates );
        next if $total ne '+' && $total ne '-';
        my @to_anot = grep { $_->tag eq $tag && ! $self->is_aspect_candidate( $_ ) } $and->get_children;
        map { $self->mark_node( $_, "coord$total" ) } @to_anot;
    }

    return 1;
}

1;

#   Vzdycky, když najdes aspekt, vsechno, co je snim v koordinaci je taky aspekt.
#
#              Pr. The excellent mussels, puff pastry, goat cheese and salad.

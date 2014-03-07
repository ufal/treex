package Treex::Block::SemevalABSA::But;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @buts = grep { $_->afun eq 'Coord' && $_->lemma eq 'but' } $atree->get_descendants;

    for my $but ( @buts ) {
        # my @preds = grep { $_->afun eq 'Pred_Co' } $but->get_children( { ordered =>1 } );
        my @preds = $but->get_children( { ordered =>1 } );
        if ( @preds == 2 ) {
            my @aspects_a = grep { $self->is_aspect_candidate( $_ ) } $preds[0]->get_descendants;
            my @aspects_b = grep { $self->is_aspect_candidate( $_ ) } $preds[1]->get_descendants;
            next if ! @aspects_a;
            if ( @aspects_b ) {
                my $total = $self->combine_polarities( map { $self->get_aspect_candidate_polarities( $_ ) } @aspects_a );
                if ( $total eq '+' || $total eq '-' ) {
                    map { $self->mark_node( $_, "but_opposite$total" ) } @aspects_b;
                }
            } else {
                map { $self->mark_node( $_, "but_conflict" ) } @aspects_a;
            }
        } else {
            log_warn "Unexpected number of clauses for node " . $but->get_attr('id') . ", skipping";
        }
    }

    return 1;
}

1;

# Pokud jsem aspekt v koordinaci s but, mam hodnotu conflict, pokud není ve druhe casti dalsi aspekt
#
#     Pr. The food was delicious, but do not come here on an empty stomach.
#
# Pokud jsem aspekt v koordinaci s but a ve druhe casti je take aspekt, mel by mit opacnou polaritu.
#
#     Pr. The food is outstanding, but everything else sucks.

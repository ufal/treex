package Treex::Block::SemevalABSA::VerbActants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_ttree {
    my ( $self, $ttree ) = @_;

    my $amapper = get_alayer_mapper( $ttree );

    my @preds = grep { $_->functor eq 'PRED' && is_subjective( $amapper->( $_ ) ) } $ttree->get_descendants;

    for my $pred (@preds) {
        my $polarity = get_polarity( $amapper->( $pred ) );
        my @actors = grep { $_->functor eq 'ACT' } get_clause_descendants( $pred );
        my @patients = grep { $_->functor eq 'PAT' } get_clause_descendants( $pred );
        if (@patients) {
            map { mark_node( $amapper->( $_ ), "verb_actant_pat$polarity" ) } @patients;
        } elsif (@actors) {
            map { mark_node( $amapper->( $_ ), "verb_actant_act$polarity" ) } @actors;
        }
    }

    return 1;
}

1;

#     Pokud jsem hodnotici sloveso ze slovniku a mam jeden aktant, je to aspekt.
#
#         Pr. Their wine sucks.
#
#   Pokud jsem hodnotici sloveso ze slovniku a jsem tranzitivni, je aspekt muj pacient.
#
#         Pr. I liked the beer selection PAT.

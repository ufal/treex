package Treex::Block::A2T::EN::DistribCoordAux;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );


############################################################################
# This block distributes also parentheses and needs functors to be filled. #
# See SxxA_to_SxxT::Move_aux_from_coord_to_members for an alternative.     #
############################################################################



sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_aux_root = $bundle->get_tree('SEnglishT');

        my %aux_not_to_move;

        foreach my $t_member_node (
            grep {
                $_->is_member
                    and $_->get_parent->get_attr('a/aux.rf')
            }
            $t_aux_root->get_descendants
            )
        {
            my $t_parent = $t_member_node->get_parent;

            # u 'as_well_as' se ta 'as' ke clenum koordinace nerozmistuji
            if ( $t_parent->t_lemma eq "as_well_as" ) {
                foreach my $as (
                    grep { $_->lemma eq "as" }
                    $t_parent->get_aux_anodes
                    )
                {
                    $aux_not_to_move{ $as->get_attr('id') } = 1;
                }
            }

            my $parentauxrfs = $t_parent->get_attr('a/aux.rf');
            next if !defined $parentauxrfs;
            my $memberauxrfs = $t_member_node->get_attr('a/aux.rf');
            next if !defined $memberauxrfs;
            $t_member_node->set_attr(
                'a/aux.rf',
                [   @$memberauxrfs,
                    grep { not $aux_not_to_move{$_} } @$parentauxrfs
                ]
            );
        }

        foreach my $t_coord_node (
            grep {
                defined $_->functor
                    and $_->functor =~ /^(CONJ|DISJ|ADVS)$/
            } $t_aux_root->get_descendants
            )
        {
            my $auxrf = $t_coord_node->get_attr('a/aux.rf');
            next if !defined $auxrf;
            $t_coord_node->set_attr(
                'a/aux.rf',
                [ grep { $aux_not_to_move{$_} } @$auxrf ]
            );
        }

    }
}

1;

=over

=item Treex::Block::A2T::EN::DistribCoordAux

In each SEnglishT tree, reference to auxiliary SEnglishA nodes shared by coordination members
(e.g. in the expression 'for girls and boys') are moved from the coordination head to the coordination
members (as if the expression was 'for girls and for boys').

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

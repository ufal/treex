package Treex::Block::A2T::EN::MarkNegatorAsAux;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );




sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $a_root = $bundle->get_tree('SEnglishA');

        foreach my $a_node ( $a_root->get_descendants ) {
            my ($eff_parent) = $a_node->get_eff_parents;
            if ($a_node->lemma
                =~ /^(not|n\'t)$/
                and $eff_parent->tag =~ /(^V)|(^MD$)/
                )
            {
                $a_node->set_attr( 'is_aux_to_parent', 1 );
            }
        }
    }
}

1;

=over

=item Treex::Block::A2T::EN::MarkNegatorAsAux


'not' is marked as aux_to_parent (which is used in the translation scenarios,
but not in preparing data for annotators)


=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

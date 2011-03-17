package Treex::Block::T2T::EN2CS::DeletePossPronBeforeVlastni;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';
use utf8;

sub process_zone {
    my ( $self, $zone ) = @_;

    # ordering needed (otherwise an already deleted node could be touched again)
    foreach my $tnode ($zone->get_ttree->get_descendants({ordered=>1})) {

        if ( $tnode->t_lemma eq 'vlastní') {
            my $prev_node = $tnode->get_prev_node;
            if ($prev_node
                    && $prev_node->t_lemma eq '#PersPron'
                        && $prev_node->get_attr('gram/person') == 3
                            && ! $prev_node->children) {
                $prev_node->delete;
            }
        }
    }
}

1;

=over

=item Treex::Block::T2T::EN2CS::DeletePossPronBeforeVlastni

Deleting possessive personal pronouns in front of 'vlastni'
(it distinguishes different meanings very rarely in Czech, in most cases it
sounds pleonastic, moreover, the selected pronoun form was
often wrong anyway, esp. because of difficult reflexivity detection)

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

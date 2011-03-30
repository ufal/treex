package Treex::Block::T2A::CS::DeleteEmptyNouns;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    my @children = $cs_tnode->get_children;

    if ( @children == 1 and $children[0]->formeme eq 'adj:attr' and $children[0]->precedes($cs_tnode) ) {
        my $en_tnode = $cs_tnode->src_tnode;
        if ( $en_tnode->t_lemma eq 'one' and my $a_node = $cs_tnode->get_lex_anode ) {
            foreach my $a_child ( $a_node->get_children ) {
                $a_child->set_parent( $a_node->get_parent );
            }

            $a_node->disconnect;
        }
    }
    return;
}

1;

__END__

=over

=item Treex::Block::T2A::CS::DeleteEmptyNouns

Delete 'empty nouns' emerging during en->cs transfer
from 'one' in constructions such as 'damaged one'.
(!!! should be moved to the transfer phase, but we don't have
any processing of empty nouns so far)

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

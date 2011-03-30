package Treex::Block::A2T::CS::MarkRelClauseHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ( $t_node->is_clause_head ) {
        if ( grep { $_->get_lex_anode && $_->get_lex_anode->tag =~ /^.[149EJK\?]/ } $t_node->get_children ) {
            $t_node->set_is_relclause_head(1);
        }
    }
}

1;

=over

=item Treex::Block::A2T::CS::MarkRelClauseHeads

Finds relative clauses and mark their heads using the C<is_relclause_head> attribute.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

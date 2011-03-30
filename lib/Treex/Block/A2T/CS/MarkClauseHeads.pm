package Treex::Block::A2T::CS::MarkClauseHeads;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ( $t_node->get_lex_anode && grep { $_->tag =~ /^V[Bp]/ } $t_node->get_anodes ) {
        $t_node->set_is_clause_head(1);
    }
}

1;

=over

=item Treex::Block::A2T::CS::MarkClauseHeads

SCzechT nodes representing the heads of finite verb clauses are marked
by the value 1 in the C<is_clause_head> attribute.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

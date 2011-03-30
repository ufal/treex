package Treex::Block::T2A::CS::ProjectClauseNumber;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $clause_number = $t_node->clause_number;
    if ( defined $clause_number ) {
        foreach my $a_node ( $t_node->get_anodes ) {
            $a_node->set_clause_number($clause_number);
        }
    }
    return;
}

1;

=over

=item Treex::Block::T2A::CS::ProjectClauseNumber

Number coindexing of finite verb clauses is projected from t-tree to a-tree.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

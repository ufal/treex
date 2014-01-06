package Treex::Block::T2A::AddParentheses;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    return if !$anode->wild->{is_parenthesis};
    my $clause_number = $anode->clause_number;

    # If a whole clause is parenthetized, then the parentheses serve as a clause boundary
    # and should have clause_number==0 ,(otherwise there would be added an extra comma).
    # So let's check whether $anode is a clause head (but the is_clause_head attribute is not filled).
    if (!$anode->get_parent->is_root() && $anode->get_parent->clause_number != $clause_number) {
        $clause_number = 0;
    }

    my $left_par = add_parenthesis_node( $anode, '(', $clause_number );
    $left_par->shift_before_subtree($anode);

    my $right_par = add_parenthesis_node( $anode, ')', $clause_number );
    $right_par->shift_after_subtree($anode);

    return;
}

sub add_parenthesis_node {
    my ( $parent, $lemma, $clause_number ) = @_;
    return $parent->create_child(
        {   'lemma'         => $lemma,
            'form'          => $lemma,
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => $clause_number,
        }
    );
}

1;

=over

=item Treex::Block::T2A::AddParentheses

Add a pair of parenthesis a-nodes, accordingly
to t-node's C<is_parenthesis> attribute.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

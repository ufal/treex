package Treex::Block::T2A::CS::AddParentheses;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'cs' );




sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $t_node ( $bundle->get_tree('TCzechT')->get_descendants() ) {
        process_tnode($t_node);
    }
    return;
}

sub process_tnode {
    my ($t_node) = @_;
    return if !$t_node->get_attr('is_parenthesis');
    my $parenthetized_aroot = $t_node->get_lex_anode();
    return if !$parenthetized_aroot;
    my $clause_number = 0;
    if ( !$t_node->is_clause_head ) {
        $clause_number = $t_node->get_attr('clause_number');
    }

    my $left_par = add_parenthesis_node( $parenthetized_aroot, '(', $clause_number );
    $left_par->shift_before_subtree($parenthetized_aroot);

    my $right_par = add_parenthesis_node( $parenthetized_aroot, ')', $clause_number );
    $right_par->shift_after_subtree($parenthetized_aroot);

    return;
}

sub add_parenthesis_node {
    my ( $parent, $lemma, $clause_number ) = @_;
    return $parent->create_child(
        {   attributes => {
                'lemma'       => $lemma,
                'form'        => $lemma,
                'afun'          => 'AuxX',
                'morphcat/pos'  => 'Z',
                'clause_number' => $clause_number,
                }
        }
    );
}

1;

=over

=item Treex::Block::T2A::CS::AddParentheses

Add a pair of parenthesis a-nodes, accordingly
to t-node's C<is_parenthesis> attribute.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

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

    # see Treex::Block::A2T::MarkParentheses, where I set $tnode->wild->{is_rightangle_bracket}
    my ($tnode) = $anode->get_referencing_nodes('a/lex.rf');
    if ($tnode and $tnode->src_tnode->wild->{is_rightangle_bracket} ) {
        my $left_par = add_parenthesis_node( $anode, '[', $clause_number );
        $left_par->shift_before_subtree($anode);

        my $right_par = add_parenthesis_node( $anode, ']', $clause_number );
        $right_par->shift_after_subtree($anode);
    } else {
        my $left_par = add_parenthesis_node( $anode, '(', $clause_number );
        $left_par->shift_before_subtree($anode);

        my $right_par = add_parenthesis_node( $anode, ')', $clause_number );
        $right_par->shift_after_subtree($anode);
    }

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

=encoding utf-8

=head1 NAME

Treex::Block::T2A::AddParentheses

=head1 DESCRIPTION

Add a pair of parenthesis a-nodes, accordingly
to t-node's C<is_parenthesis> attribute.

Add a pair of right angle bracket is_rightangle_bracket

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

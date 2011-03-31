package Treex::Block::T2A::DeleteGeneratedNodes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

Readonly my $LEMMAS_TO_REMOVE => {
    '#AsMuch'  => 1,
    '#Benef'   => 1,
    '#Cor'     => 1,
    '#EmpNoun' => 1,
    '#EmpVerb' => 1,
    '#Equal'   => 1,
    '#Gen'     => 1,
    '#Oblfm'   => 1,
    '#Qcor'    => 1,
    '#Rcp'     => 1,
    '#Separ'   => 1,
    '#Some'    => 1,
};    # the t-lemmas of the nodes to be deleted

Readonly my $FUNCTORS_PRIORITY => {
    'ACMP'   => 5,
    'ACT'    => 9,
    'ADDR'   => 7,
    'ADVS'   => 10,
    'AIM'    => 5,
    'APP'    => 5,
    'APPS'   => 10,
    'ATT'    => 1,
    'AUTH'   => 5,
    'BEN'    => 5,
    'CAUS'   => 5,
    'CNCS'   => 5,
    'CM'     => 1,
    'COMPL'  => 5,
    'COND'   => 5,
    'CONFR'  => 10,
    'CONJ'   => 10,
    'CONTRA' => 10,
    'CONTRD' => 5,
    'CPHR'   => 10,
    'CPR'    => 5,
    'CRIT'   => 5,
    'CSQ'    => 10,
    'DENOM'  => 10,
    'DIFF'   => 5,
    'DIR1'   => 5,
    'DIR2'   => 5,
    'DIR3'   => 5,
    'DISJ'   => 10,
    'DPHR'   => 10,
    'EFF'    => 6,
    'EXT'    => 5,
    'FPHR'   => 1,
    'GRAD'   => 10,
    'HER'    => 5,
    'ID'     => 1,
    'INTF'   => 1,
    'INTT'   => 5,
    'LOC'    => 5,
    'MANN'   => 5,
    'MAT'    => 9,
    'MEANS'  => 5,
    'MOD'    => 1,
    'OPER'   => 10,
    'ORIG'   => 6,
    'PAR'    => 10,
    'PARTL'  => 10,
    'PAT'    => 8,
    'PREC'   => 1,
    'PRED'   => 10,
    'REAS'   => 10,
    'REG'    => 5,
    'RESL'   => 5,
    'RESTR'  => 5,
    'RHEM'   => 1,
    'RSTR'   => 5,
    'SUBS'   => 5,
    'TFHL'   => 5,
    'TFRWH'  => 5,
    'THL'    => 5,
    'THO'    => 5,
    'TOWH'   => 5,
    'TPAR'   => 5,
    'TSIN'   => 5,
    'TTILL'  => 5,
    'TWHEN'  => 5,
    'VOCAT'  => 10
};    # functors priority for collapsing the children under the most important one
      # (highest priority: roots of various structures, then actants - ACT > PAT > ADDR > rest, then modifiers,
      # least - rhematizers and similar)

sub process_ttree {

    my ( $self, $t_root ) = @_;

    $self->_process_subtree($t_root);
    return;
}

# (Recursively) processes a subtree by DFS, looking for nodes to be removed and removing them.
sub _process_subtree {

    my ( $self, $t_node ) = @_;
    my @children = $t_node->get_children( { ordered => 1 } );

    foreach my $child (@children) {

        $self->_process_subtree($child);
        if ( $child->is_generated and ( $child->t_lemma =~ m/^[^#]/ or $LEMMAS_TO_REMOVE->{ $child->t_lemma } ) ) {
            $self->_remove_node( $t_node, $child );
        }
    }
    return;
}

# Removes the node, arranging its children in various ways.
sub _remove_node {

    my ( $self, $parent, $to_remove ) = @_;

    my @children = $to_remove->get_children( { ordered => 1 } );
    my $rewrite_functor = $to_remove->t_lemma eq '#Equal' ? $to_remove->functor : 0;

    if ( @children > 0 ) {

        if ( $to_remove->functor eq 'PRED' ) {    # elided predicates -> rehang other children to ACT or the first one

            my $most_important = $self->_find_most_important_child( \@children );
            $most_important->set_parent($parent);    # rehang the others
            for my $child (@children) {
                if ( $child != $most_important ) {
                    $child->set_parent($most_important);
                }
            }
        }
        elsif ( $to_remove->t_lemma =~ m/^[^#]/ ) {    # elided actucal words -> rehang other children to the last one
            $children[ @children - 1 ]->set_parent($parent);
            for ( my $i = 0; $i < @children - 1; ++$i ) {
                $children[$i]->set_parent( $children[ @children - 1 ] );
            }
        }
        else {                                         # other cases: rehang all children to parent
            foreach my $child (@children) {
                $child->set_parent($parent);

                if ($rewrite_functor) {                # rewrite functor for '#Equal'
                    $child->set_functor($rewrite_functor);
                }
            }
        }
    }
    $to_remove->remove();
    return;
}

# Find the most important child in terms of functors priority (see $FUNCTORS_PRIORITY) and order (later is more important)
sub _find_most_important_child {

    my ( $self, $children ) = @_;
    my $most_important = $children->[0];

    for my $child ( @{$children} ) {
        if ( $FUNCTORS_PRIORITY->{ $child->functor } >= $FUNCTORS_PRIORITY->{ $most_important->functor } ) {
            $most_important = $child;
        }
    }
    return $most_important;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::DeleteGeneratedNodes

=head1 DESCRIPTION

This block deletes all generated nodes from the PDT/PEDT sentence representation that are not used in the 
current Treex/TectoMT analyses (i.e. elided words / obligatory actors etc.). 

Any children of the deleted node are hanged to its parents for most types of deleted nodes, except in the following case:
For elided predicates or if , all other children are rehanged to the 'most important' one. The importance of the children
is based on their functors (ACT > PAT > other actants > adverbials) and their order. 

The functor of the deleted #Equal nodes (usually MANN) is propagated to the remaining children.

=head1 TODO

The functor priority should require more testing; shouldn't some more functors be propagated to their children?

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

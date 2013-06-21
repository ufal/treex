package Treex::Block::A2N::NestEntities;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_ntree {
    my ( $self, $n_root ) = @_;
    my @n_nodes = $n_root->get_descendants();
    
    # Entity A is a descendant (child, grandchild,...) of B iff
    # a-nodes(A) is a proper subset of a-nodes(B).
    # However, current NERs support only contiguous entities,
    # so it is sufficient to remember the position
    # of the first (%start) and last (%end) a-node.
    my (%start, %end, %length);
    foreach my $n_node (@n_nodes){
        my @a_nodes = sort {$a->ord <=> $b->ord} $n_node->get_anodes();
        
        # Some NERs fail to fill a-node links to "container" entities.
        if (!@a_nodes){
            log_fatal $n_node->id . ' has no links to a-nodes (use A2N::FixMissingLinks first)';
        }

        # Remember the start and end positions as well as the length.
        $start{$n_node}  = $a_nodes[0]->ord;
        $end{$n_node}    = $a_nodes[-1]->ord;
        $length{$n_node} = $a_nodes[-1]->ord - $a_nodes[0]->ord + 1;
    }
    
    # Sort n-nodes start the shortest to the longest.
    @n_nodes = sort {$length{$a} <=> $length{$b}} @n_nodes;
    
    # Flatten the n-tree to prevent cycles.
    for (@n_nodes){$_->set_parent($n_root);}
    
    # For each n-node check all other n-nodes if they are its parent
    # (the shortest valid parent is selected).
    # The quadratic complexity is OK given just a handful of entities in one sentence.
    foreach my $i_child (0..$#n_nodes-1){
        my $child = $n_nodes[$i_child];
        PARENT:
        foreach my $i_parent ($i_child+1 .. $#n_nodes){
            my $parent = $n_nodes[$i_parent];
            if (   $length{$child} < $length{$parent}
                && $start{$parent} <= $start{$child}
                && $end{$parent} >= $end{$child}
            ){
                $child->set_parent($parent);
                last PARENT;
            }
        }
    }
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::NestEntities - nested entities should be parent-child in n-trees

=head1 DESCRIPTION

Nested named entities should be represented in n-trees using the parent-child relationship.
For example, in sentence I<Sir Mervyn Allister King is the Governor of the Bank of England>,
the proper nesting is

 PM(pd(Sir) pf(Mervyn) pm(Allister) ps(King)) is the P(Governor of the io(Bank of gc(England)))

           n-root
         /        \
      PM           P
   / |  | \        |
 pd pf  pm ps      io
                   |
                   gc
 
However, some NER output always a "flat" n-tree (with all entities being children of the n-root):

            n-root
   /  /  /  / |  \ \  \
 pd pf PM pm ps  P io gc

This block fixes the error and converts the flat n-tree into properly nested n-tree. 

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

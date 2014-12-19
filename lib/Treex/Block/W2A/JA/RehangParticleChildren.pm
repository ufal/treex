package Treex::Block::W2A::JA::RehangParticleChildren;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

# While recursively depth-first-traversing the tree
# we sometimes rehang already processed parent node as a child node.
# But we don't want to process such nodes again.
my %is_processed;

sub process_atree {
    my ( $self, $a_root ) = @_;
    %is_processed = ();
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;

    if ( should_move($a_node) ) {
      move_downwards($a_node);
    }
    if ( should_switch_with_parent($a_node) ){
      switch_with_parent($a_node);       
    }

    $is_processed{$a_node} = 1;
 
    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }

    return;
}

sub should_move {
    my ($a_node) = @_;
    my $next = $a_node->get_next_node();
    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # particle can be a parent only when it is directly behind its child
    return 0 if ($parent->tag !~ /^Joshi/ || $parent == $next);

    # if the parent is a coordination particle, we do nothing
    return 0 if  $parent->tag =~ /Heiritsujoshi/;

    return 1;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # adverbial particles probably shouldn't have any children, so if one is a parent, we switch a child with it
    return 1 if $parent->tag =~ /^Joshi-FukuJoshi/;

    # we also want rehang interpunciton in the same manner (even though it should be in an independent block)
    return 0 if ($parent->tag !~ /^Kigō/ || $a_node->get_next_node() != $parent);

    return 1;
}

sub move_downwards {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    my $new_parent = $parent->get_prev_node();

    # the new parent should not be a particle
    while ($new_parent->tag =~ /^Joshi/) { 
      $new_parent = $new_parent->get_prev_node();
    }
    
    $a_node->set_parent($new_parent);

    return;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();

    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    # all the children of the old parent should be suspended under the node
    foreach my $child ($parent->get_children()) {
      $child->set_parent($a_node);
    }
    
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::RehangParticleChildren - Modifies position of tokens which are wrongly dependent on the particles. 

=head1 DESCRIPTION

Modifies the topology of trees parsed by Cabocha parser.
Blocks W2A::JA::RehangConjunctions and W2A::JA::RehangCopulas should be applied first.
This block rehangs tokens which should not be dependent on any particles.
If a node is dependent on a particle which is not directly following the node,
its parent is set to a child of that particle.
Therefore only the coordination particles should have more than one child.

Furthermore, adverbial particles (Fukujoshi) should not have any children, so this block switches its child with them.

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

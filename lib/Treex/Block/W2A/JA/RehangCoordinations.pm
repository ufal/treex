package Treex::Block::W2A::JA::RehangCoordinations;

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

    my @children = $a_root->get_children();
    for (my $i = (scalar @children) - 1; $i >= 0; $i--) {
        fix_subtree($children[$i]);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;

    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }
    $is_processed{$a_node} = 1;
 
    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }

    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    my $form = $a_node->form;
    return 0 if $tag !~ /Heiritsujoshi/;

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    my $parent = $a_node->get_parent();

    # there should be two possible coordinations patterns:
    # 1) <token1> PARTICLE <token2> (... PARTICLE <tokenN>) <case_particle/modifier/copula>:
    if (!$parent->is_root()) {
      my $granpa = $parent->get_parent();
      my $parent_tag = $parent->tag;
      $parent_tag =~ s/-.*//;

      foreach my $child ( $a_node->get_children() ) {

        # in this case, the particle should only have only one child, it should have same base tag as the parent
        if ( $child->tag =~ /$parent_tag/ ) {
          $child->set_is_member(1);
          $parent->set_is_member(1);
          $a_node->set_parent($granpa);
          $parent->set_parent($a_node);
          last;
        }
      
      }
    }


    # 2) <token1> PARTICLE <token2> PARTICLE ...
    # we can also get this pattern after the rehanging of 1)
    foreach my $child ( $a_node->get_children() ) {
    
      # if a child node is also coordination particle, we rehang its children to its parent
      if ( $child->tag =~ /Heiritsujoshi/ ) {
        foreach my $grandchild ( $child->get_children() ) {
          $grandchild->set_parent($a_node);
          $grandchild->set_is_member(1) if $grandchild->tag !~ /Heiritsujoshi/;
        }
      }

    }

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::RehangCoordinations - Modifies location of coordinations within an a-tree, and sets value of is_member attribute for coordinated nodes

=head1 DESCRIPTION

Modifies the topology of the parsed trees, so it is closer to that of PDT annotation scheme.

=head1 TODO

More complex coordination structures still needs to be examined.
Block is still being tested

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut


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

    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }

    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }

    # sometimes not all coordinates have attribute is_member set correctly
    fix_is_member($a_node);

    $is_processed{$a_node} = 1;
 
    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    my $form = $a_node->form;

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    return 0 if $tag !~ /Heiritsujoshi/;

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    my $parent = $a_node->get_parent();

    # there should be two possible coordinations patterns:
    # 1) <token1> PARTICLE <token2> (... PARTICLE <tokenN>) <case_particle/modifier/copula>:
    # <token1> -> PARTICLE -> <token2>
    if ( $parent->tag !~ /Heiritsujoshi/ ) {
      my $granpa = $parent->get_parent();
      my $parent_tag = $parent->tag;
      $parent_tag =~ s/-.*//;

      my $is_coord = 0;
      foreach my $child ( $a_node->get_children() ) {
        if ($child->tag =~ /$parent_tag/) {
          $child->set_is_member(1);
          $is_coord = 1;
        }
      }
      if ($is_coord) {
        $parent->set_is_member(1);
        $a_node->set_parent($granpa);
        $parent->set_parent($a_node);
      }

      return; 
    }

    # 2) <token1> PARTICLE1 <token2> PARTICLE2...
    # <token1> -> PARTICLE -> PARTICLE <- <token2>
    foreach my $child ( $a_node->get_children() ) {
      $child->set_parent($parent);
      $child->set_is_member(1) if $child->tag !~ /Heiritsujoshi/;
    }

    return;
}

sub fix_is_member() {
  my ($a_node) = @_;
  return if $a_node->tag !~ /Heiritsujoshi/;

  foreach my $child ($a_node->get_children()) {
    if ($child->tag !~ /^Joshi/) {
      $child->set_is_member(1);
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


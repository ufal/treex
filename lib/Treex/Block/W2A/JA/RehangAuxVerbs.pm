package Treex::Block::W2A::JA::RehangAuxVerbs;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;

extends 'Treex::Core::Block';

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

    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }
    elsif ( should_switch_with_child($a_node) ) {
        switch_with_child($a_node);
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
    return 0 if ( $tag !~ /^Dōshi-HiJiritsu/ );

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # check, if our verb is dependent on a non-independent verb (non-pure auxiliary, e.g. "iru", "aru") or suffix-verb (pure auxiliary, e.g. "rareru", "saseru")
    return 0 if ($parent->tag !~ /-Jiritsu/ && $parent->tag !~ /-Setsubi/);

    return 1;
}

sub should_switch_with_child {
  my ($a_node) = @_;
  my $tag = $a_node->tag;
  my $lemma = $a_node->lemma;
  my @children = $a_node->get_children();

  return 0 if ( $tag !~ /Jodōshi/ );

  # we do not rehang copulas
  return 0 if ( $lemma eq "です" || $lemma eq "だ" );

  return 0 if ( scalar @children == 0 );

  return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();
    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    return;
}

sub switch_with_child {
  my ($a_node) = @_;
  my $parent = $a_node->get_parent();
  my @children = $a_node->get_children();
  
  # if there are more children, we want to take the rightmost one
  my $child = pop @children;
  $child->set_parent($parent);
  $a_node->set_parent($child);

  # we rehang the rest of the children
  foreach my $ch (@children) {
    $ch->set_parent($child);
  }

  return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::RehangAuxVerbs - Modifies the position of auxiliary and non-independent verbs within an a-tree.

=head1 DESCRIPTION

Verbs (Dōshi) with tag Dōshi-Jiritsu (independent) should be dependent
on the non-independent verbs (tag Dōshi-HiJiritsu), which are similar to english modal verbs. 
Auxiliaries (Jodōshi) should never have any children.
This block takes care of that.

---

Suggested order of applying Rehang* blocks:
W2A::JA::RehangAuxVerbs
W2A::JA::RehangCopulas
W2A::JA::RehangParticles

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

package Treex::Block::W2A::JA::RehangConjunctions;
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

# We process only conjunctive articles here

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
    
    my @children = $a_node->get_children();
    # since Japanese is head-final, we prefer to go through children
    # in a reverse order
    for (my $i = (scalar @children) - 1; $i >= 0; $i--) {
        next if $is_processed{$children[$i]};
         
        fix_subtree($children[$i]);
    }
    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    my $form = $a_node->form;
    return 0 if ($tag !~ /^Joshi-SetsuzokuJoshi/ && $tag !~ /^Joshi-Heiritsujoshi/ && $tag !~ /^Setsuzokushi/);

    # 接続詞 - Setsuzokushi - conjunction (sentence introduction)
    # 助詞-接続助詞 - Joshi-SetsuzokuJoshi - particle-conjunctive
    # 助詞-並立助詞 - Joshi-Heiritsujoshi - particle-coordinate

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # we need to treat "て" particle differently, if its just a part of "continuous" form of a verb (e.g. verb + て + います).
    if ( $form eq "て" ) {
      
      # note that a possible non-independent verb (e.g. います) should be already sibling of "て" particle, thanks to W2A::JA::RehangAuxVerbs
      foreach my $child ($parent->get_children()) {
        return 0 if $child->tag =~ /HiJiritsu/;
      }
    }

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;


    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();
    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    # for coordination particles, we further change topology:
    # we want both coordinated nodes to be dependent on the particle
    if ($tag =~ /-Heiritsujoshi/) {
      $parent = $a_node->get_parent();
      $granpa = $parent->get_parent();
      $a_node->set_parent($granpa);
      $parent->set_parent($a_node);

      # we must set IsMember for both coordinated nodes
      foreach my $child ( $a_node->get_children() ) {
        $child->set_is_member(1);
      }

      $parent = $a_node->get_parent();

      # in case of multiple coordinations we rehang children of the particle to the higher coordination particle
      if ($parent->tag && $parent->tag =~ /-Heiritsujoshi/) {
        foreach my $child ( $a_node->get_children() ) {
          $child->set_parent($parent);
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

Treex::Block::W2A::JA::RehangConjunctions

=head1 DESCRIPTION

Modifies the topology of trees parsed by JDEPP parser so it easier to work with later (transforming to t-layer, transfer ja2cs).
We pay special attention to coordinating particles and treat them in a similar manner as in PDT.

Block shouldn't be called before blocks Treex::Block::W2A::JA::RehangCopulas Treex::Block::W2A::JA::RehangAuxVerbs have been applied

=head1 TODO

Fix default JDEPP coordination dependencies.
  鳥や 犬や 猫や 馬が いました - There were horses and dogs and cats and birds.
  birdsや dogsや catsや horsesや to_be.

  JDEPP:
    birds   -> to_be
    dogs    -> horses
    cats    -> horses
    horses  -> to_be
  We desire: (for correct coord. particle modification)
    birds   -> horses
    dogs    -> horses
    cats    -> horses
    horses  -> to_be

More complex coordination structures needs to be examined (JDEPP output).
Block is still being tested

=head1 AUTHORS

Dusan Varis

=cut


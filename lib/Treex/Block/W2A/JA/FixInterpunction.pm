package Treex::Block::W2A::JA::FixInterpunction;
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

# we change "。", "？" and "！" to ".", "?" and "!"
# we also rehang them to the root 

sub process_atree {
  my ( $self, $a_root ) = @_;
  foreach my $a_node ( $a_root->get_descendants() ) {
    
    next if ( $a_node->form !~ /[。？！]/ );

    # we do not want Interpunction nodes to have children, so we rehang
    # them to the previous parent
    my $parent = $a_node->get_parent();
    my @children = $a_node->get_children();
 
    # set new parent for the children (since japanese is head final,
    # it should be the last child)
    my $new_parent;
    if (@children) {
      $new_parent = pop @children;
      $new_parent->set_parent($parent) if ($new_parent);
    }

    # rehang the rest of the children
    foreach my $child (@children) {
      $child->set_parent($new_parent);
    }


    if ( $a_node->form eq "。" and $a_node->tag =~ /^Kigō/ ) {
      $a_node->set_form(".");
      $a_node->set_lemma(".");
      $a_node->set_parent($a_root);
    }
    if ( $a_node->form eq "？" and $a_node->tag =~ /^Kigō/ ) {
      $a_node->set_form("?");
      $a_node->set_lemma("?");
      $a_node->set_parent($a_root);
    }
    if ( $a_node->form eq "！" and $a_node->tag =~ /^Kigō/ ) {
      $a_node->set_form("!");
      $a_node->set_lemma("!");
      $a_node->set_parent($a_root);
    }

  }
  return 1;
}

1;

__END__

=pod

=head1 NAME

Treex::Block::W2A::JA::FixInterpunction

=head1 DECRIPTION

Changes the form and lemma of the interpunction from their japanese-encoding
equivalents.
Also, if interpunction node has children, they are rehanged.

=head1 AUTHORS

Dusan Varis

=cut

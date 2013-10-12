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
    return 0 if $tag !~ /^Joshi_Setsuzoku/;

    # we need to treat "て" particle differently
    return 0 if $form eq "て";

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # All particles processed in following steps must stand after the word to which they are related
    return 0 if $a_node->precedes($parent);

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

1;

__END__

=over

=item Treex::Block::W2A::JA::RehangConjunctions

Modifies the topology of trees parsed by JDEPP parser so it easier to work with later (transforming to t-layer, transfer ja2cs).
So far it only rehangs conjunctive particles used between words.
(TODO: correct some special cases, take care of conjuncions between two sentences)

=back

=cut

# Author: Dusan Varis

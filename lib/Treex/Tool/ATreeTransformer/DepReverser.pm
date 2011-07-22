package Treex::Tool::ATreeTransformer::DepReverser;

use Moose;
use Treex::Core::Log;

has nodes_to_reverse => (
    is => 'rw',
    isa => 'CodeRef',
    required => 1,
    documentation => 'subroutine recognizing node pairs (a node N and its effective parent P) to swap',
);

has move_with_child => (
    is => 'rw',
    isa => 'CodeRef',
    default => sub { 0 },
    documentation => 'subroutine identifying N\'s children to be moved up together with their parent',
);

has move_with_parent => (
    is => 'rw',
    isa => 'CodeRef',
    default => sub { 0 },
    documentation => 'subroutine identifying P\'s children to be moved down together with their parent',
);


sub _reverse_nodes {
    my ($self, $child, $parent) = @_;

    $child->set_parent($parent->get_parent);

    my @move_below_original_parent = grep {!&{$self->move_with_child}($_)} $child->get_children;
    my @move_below_original_child = grep {!&{$self->move_with_parent}($_)} $parent->get_children;

    $parent->set_parent($child);

    foreach my $node (@move_below_original_child) {
        $node->set_parent($child);
    }

    foreach my $node (@move_below_original_parent) {
        $node->set_parent($parent);
    }

    $child->set_is_member($parent->is_member);
    $parent->set_is_member(undef); # the original child's is_member is never true
}

sub apply_on_tree {
    my ($self, $root) = @_;

    my @pairs_to_swap;
    my %node_to_swap;

    foreach my $child ( grep { !$_->is_member }
                            map {$_->get_descendants} # tech.root can't be swapped with its child
                                $root->get_children) {

        my $parent = $child->get_parent;

        my @expanded_children = $child->get_coap_members;
        my @expanded_parents = $parent->get_coap_members;

        my ($pairs, $pairs_to_swap) = (0,0);

        foreach my $expanded_child (@expanded_children) {
            foreach my $expanded_parent (@expanded_parents) {
                $pairs++;
                if (&{$self->nodes_to_reverse}($expanded_child, $expanded_parent)) {
                    $pairs_to_swap++
                }
            }
        }

        if (not $pairs) {
            log_fatal('No node pairs after combining parent and child expansions (sanity check)');
        }

        if ( $pairs_to_swap > 0 ) {

            if ( $pairs_to_swap < $pairs ) {
                log_warn('Conflicting instructions for child-parent swap in a coordination construction');
            }
            elsif ($node_to_swap{$child} or $node_to_swap{$parent}) {
                log_warn('A node can not participate in two swaps. The second attempt is skipped.');
            }
            else {
                $node_to_swap{$child} = 1;
                $node_to_swap{$parent} = 1;
                push @pairs_to_swap, [ $child, $parent ];
            }
        }
    }

    foreach my $pair (@pairs_to_swap) {
        $self->_reverse_nodes(@$pair);
    }

}


1;

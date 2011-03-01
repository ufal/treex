package Treex::Tools::Algorithm::TreeViterbi;

use strict;
use warnings;
use utf8;

my $get_states_hook;

sub run {
    my ($root, $get_states_sub_ref) = @_;
    $get_states_hook = $get_states_sub_ref;
    return _process_subtree($root);
}

sub _process_subtree {
    my ($node) = @_;
    my @states = $get_states_hook->($node);

    foreach my $child ($node->get_children()) {
        my @child_states = _process_subtree($child);
        _process_states( \@states, \@child_states );
    }

    foreach my $my_state ( @states ) {
        $my_state->increment_score($my_state->get_logprob());
    }

    return @states;
}

sub _process_states {
    my ( $states_ref, $child_states_ref ) = @_;

    foreach my $my_state ( @{$states_ref} ) {
        my ( $max_score, $best_child_state ) = ( -9999, undef );

        foreach my $child_state (@{$child_states_ref}) {
            my $score = $child_state->score;
            $score += $child_state->get_logprob_given_parent($my_state);
            if ( $score > $max_score ) {
                ( $max_score, $best_child_state ) = ( $score, $child_state );
            }
        }
        $my_state->add_backpointer($best_child_state);
        $my_state->increment_score($max_score);
    }
    return;
}


1;

__END__

=head1 NAME

Treex::Tools::Algorithm::TreeViterbi - algorithm for finding optimal hidden states of Hidden Markov Tree Model

=head1 VERSION

0.03

=head1 SYNOPSIS

 use Treex::Tools::Algorithm::TreeViterbi;
 my @states = Treex::Tools::Algorithm::TreeViterbi::run( $root, \&get_states_of );

 # This function is passed as a hook to TreeViterbi algorithm
 sub get_states_of {
    my ($node) = @_;
    return ...
 }

 # Now follow backpointers to optimal states
 while (@states) {
     my $state = shift @states;
     push @states, @{ $state->get_backpointers() };
     my $node = $state->get_node();
     # Do some changes to the $node
     # according to its optimal (hidden) $state
 }

=head1 DESCRIPTION

Hidden Markov Tree Models (HMTMs) are analogic to well known Hidden Markov Models (HMM),
but instead of a linear chain of observations (and corresponding hidden states )
there is a tree of observations. For more info see e.g.
Jean-Baptiste Durand, Paulo Goncalves, and Yann Guedon. 2004.
"Computational methods for hidden markov tree models - an application to wavelet
trees". IEEE Transactions on Signal Processing,  52(9):2551–2560.

Tree-modified Viterbi is analogic to the well known Viterbi algorithm,
but it operates on HMTM (instead of HMM).

This implementation of Tree-Viterbi is quite simple and flexible.
You can define your own states as well as transition and emission probabilities.

=head1 FUNCTIONS

This module has only one public function:

=over

=item my @root_states = Treex::Tools::Algorithm::TreeViterbi::run($root, $get_states_ref)

Its first argument is the root of the tree to be processed.
Its second argument is a reference to a subroutine which
returns a set of possible hidden states for a given node.
Requirements for these arguments are specified later. 

Function C<run> returns a list of possible hidden states of the root node.
It is the same list as would return C<get_states_ref-E<gt>($root)>,
but the method L<"add_backpointer"> was called on all of these states,
so now it is possible to backtrack the optimal choice of hidden states.

=back

=head1 REQUIREMENTS

There are some methods that must every node/state implement:


=head2 Method of tree nodes 

=over

=item  @child_nodes = $node->get_children()

=back

=head2 Methods of states

=over

=item $state->get_logprob()

Get emission logprob of this hidden state
(given the observable state, which should be saved in the corresponding node).

=item $state->get_logprob_given_parent($parent_state)

Get transition logprob, ie. logprob of this state given its
parent node's hidden state is C<$parent_state>. 

=item $state->get_score()

Get the score accumulated so far.

=item $state->increment_score($plus)

Increment the score by C<$plus>.

=item $state->add_backpointer($child_state)

Store a backpointer to the best (hidden) state of a child node.
Let C<Np> be a node with child nodes C<Nc_1,...,Nc_x>
and C<$state> be one of possible hidden states of C<Np>.
Then during the work of TreeViterbi algorithm,
the method C<$state-E<gt>add_backpointer($child_state)> is called exactly
C<x>-times. Each time C<$child_state> represents the choosen (the "best")
state of the node C<Nc_i> (where C<i=1,...,x>).

=back

=head1 SEE ALSO

=over

=item L<Treex::Tools::Algorithm::TreeViterbiState|Treex::Tools::Algorithm::TreeViterbiState> utility base class of (hidden) states

=item L<Treex::Block::T2T::EN2CS::TrLFTreeViterbi|Treex::Block::T2T::EN2CS::TrLFTreeViterbi> for an example of usage

=back

=head1 AUTHOR

Martin Popel

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

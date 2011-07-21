package Treex::Tool::Algorithm::TreeViterbiState;
use Moose;
use Treex::Core::Common;

has 'node'         => ( is => 'ro', );
has 'score'        => ( is => 'rw', default => 0 );
has 'backpointers' => ( is => 'ro', default => sub { [] } );

sub increment_score {
    my ( $self, $plus ) = @_;
    $self->set_score( $self->score + $plus );
    return;
}

sub add_backpointer {
    my ( $self, $state ) = @_;
    push @{ $self->backpointers }, $state;
    return;
}

sub get_logprob {
    log_fatal('TreeViterbiState can not be used directly. Use a derived class and implement get_logprob*.');
}

sub get_logprob_given_parent {
    log_fatal('TreeViterbiState can not be used directly. Use a derived class and implement get_logprob*.');
}

1;

__END__

=pod

=head1 NAME

Treex::Tool::Algorithm::TreeViterbiState - state for use in TreeViterbi algorithm

=head1 VERSION

0.03

=head1 DESCRIPTION

This is base class for use in L<Treex::Tool::Algorithm::TreeViterbi> algorithm.
In derived class all you need to implement are methods:

=over

=item $state->get_logprob()

Get emission logprob of this hidden state
(given the observable state, which should be saved in the corresponding node).

=item $state->get_logprob_given_parent($parent_state)

Get transition logprob, ie. logprob of this state given its
parent node's hidden state is C<$parent_state>. 

=back

=head1 METHODS

=over

=item $state->node()

=item $state->score()

=item $state->backpointers()

=item $state->add_backpointer($new_backpointer_to_child_state)

=item $state->increment_score($plus_logprob)

=back

=head1 AUTHOR

Martin Popel

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

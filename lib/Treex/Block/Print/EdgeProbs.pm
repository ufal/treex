package Treex::Block::Print::EdgeProbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

has _edge => ( is => 'ro', default => sub { {} } );
has _nodes => ( is => 'ro', writer => '_set_nodes', default => 0 );

sub process_anode {
    my ( $self, $anode ) = @_;
    my $parent = $anode->get_parent();
    return if $parent->is_root();
    my $edge = $self->_edge;
    $edge->{ $anode->ord - $parent->ord }++;
    $self->_set_nodes( $self->_nodes + 1 );
    return;
}

sub process_end {
    my ($self) = @_;
    my $edge   = $self->_edge;
    my $nodes  = $self->_nodes;
    for my $length ( sort { $a <=> $b } keys %{$edge} ) {
        my $prob = $edge->{$length} / $nodes;
        print { $self->_file_handle } "$length\t$prob\n";
    }
}

1;

=head1 NAME

Treex::Block::Print::EdgeProbs

=head1 DESCRIPTION

Prints probabilities of edge lengths (measured in words).

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

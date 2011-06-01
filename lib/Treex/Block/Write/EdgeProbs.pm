package Treex::Block::Write::EdgeProbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub build_language { return log_fatal "Parameter 'language' must be given"; }

my %edge;
my $nodes;

sub process_anode {
    my ( $self, $anode ) = @_;
    my $parent = $anode->get_parent();
    return if $parent->is_root();
    $edge{ $anode->ord - $parent->ord }++;
    $nodes++;
    return;
}

END {
    for my $length ( sort { $a <=> $b } keys %edge ) {
        my $prob = $edge{$length} / $nodes; 
        print "$length\t$prob\n";
    }
}

1;

=head1 NAME

Treex::Block::Write::EdgeProbs

=head1 DESCRIPTION

Prints probabilities of edge lengths (measured in words).

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

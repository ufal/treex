package Treex::Block::Align::AlignForward;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => 'Treex::Type::Layer', default => 'a' );

has '+language'   => ( required => 1 );

has 'overwrite' => ( is => 'ro', isa => 'Bool', default => 1 );

sub process_zone {
    my ( $self, $zone ) = @_;
    my @nodes = $zone->get_tree( $self->layer )->get_descendants( { ordered => 1 } );

    foreach my $x (@nodes){

        my ($ys) = $x->get_aligned_nodes();
        foreach my $y (@{$ys}){
            $y->add_aligned_node($x, 'reverse_alignment');
        } 
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::ReverseAlignment

=head1 DESCRIPTION

Reverses an alignment -- adds links from the other direction.

=head1 PARAMETERS

=item C<layer>

The layer of the aligned trees (default: a).

=item C<language>

The current language. This parameter is required.

=item C<selector>

The current selector (default: empty).

=item C<overwrite>

Toggle overwrite current alignment links (default: 1).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

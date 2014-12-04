package Treex::Block::Align::AlignForward;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => 'Treex::Type::Layer', default => 'a' );

has '+language' => ( required => 1 );

has 'overwrite' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'keep_if_no_other' => ( is => 'ro', isa => 'Bool', default => 0 );

has 'preserve_type' => ( is => 'ro', isa => 'Bool', default => 1 );

has align_type => ( is => 'rw', isa => 'Str', default => 'align_forward' );

sub process_zone {
    my ( $self, $zone ) = @_;
    my @nodes = $zone->get_tree( $self->layer )->get_descendants( { ordered => 1 } );

    foreach my $x (@nodes) {
        
        my ( $ys, $ytypes ) = $x->get_aligned_nodes();
        next if (!$ys); 

        for ( my $i = 0; $i < @{$ys}; ++$i ) {

            my ( $y, $ytype ) = ( $ys->[$i], $ytypes->[$i] );

            my ($zs) = $y->get_aligned_nodes();
            foreach my $z ( @{$zs} ) {
                $x->add_aligned_node( $z, $self->preserve_type ? $ytype : $self->align_type );
            }

            if ( $self->overwrite && ( ( $zs && scalar( @{$zs} ) ) || !$self->keep_if_no_other ) ) {
                $x->delete_aligned_node($y);
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::AlignForward

=head1 DESCRIPTION

Replaces two steps of alignment with one (e.g.: X -> Y -> Z to X -> Z). Uses all aligned nodes and all
their aligned nodes for each source node. 

The alignment type can be either changed to "align_forward", or left as the original type of first
link going from the source node. 

=head1 PARAMETERS

=item C<layer>

The layer of the aligned trees (default: a).

=item C<language>

The current language. This parameter is required.

=item C<selector>

The current selector (default: empty).

=item C<overwrite>

Toggle overwrite current alignment links (default: 1).

=item C<preserve_type>

Toggle preserve alignment type (default: 1). If this is off, the new alignment type will be changed to
'align_forward'.

=item C<keep_if_no_other>

If there is no continuing link, keep current links even if C<overwrite=1>? This is off by default.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

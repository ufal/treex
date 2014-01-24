package Treex::Block::Filter::Generic::HeadSwapRatio;
use Moose;
use Treex::Core::Common;
use Treex::Block::Filter::Generic::Common;

extends 'Treex::Block::Filter::Generic::Common';

my @bounds = ( 0, 0.2, 0.5, 0.8, 1 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my ( $pairs, $swaps ) = ( 0, 0 );

    my @parents = $bundle->get_zone($self->to_language)->get_atree->get_descendants( { ordered => 1 } );

    for my $parent ( @parents ) {
        next if ! $parent->get_attr( 'alignment' );
        for my $child ( $parent->get_children() ) {
            next if ! $child->get_attr( 'alignment' );
            for my $parent_link ( @{ $parent->get_attr( "alignment" ) } ) {
                for my $child_link ( @{ $child->get_attr( "alignment" ) } ) {
                    # only care about points included in GDFA alignment
                    my $in_gdfa_parent = grep { $_ eq "gdfa" } split /\./, $parent_link->{"type"};
                    my $in_gdfa_child = grep { $_ eq "gdfa" } split /\./, $child_link->{"type"};
                    next if ! $in_gdfa_parent || ! $in_gdfa_child;

                    my $parent_cp_id = $parent_link->{"counterpart.rf"};
                    my $child_cp_id = $child_link->{"counterpart.rf"};
                    my $parent_cp = $bundle->get_document->get_node_by_id( $parent_cp_id );
                    my $child_cp = $bundle->get_document->get_node_by_id( $child_cp_id );

                    if ( grep { $_ eq $child_cp_id } map { $_->{id} } $parent_cp->get_children() ) {
                        $pairs++;
                    } elsif ( grep { $_ eq $parent_cp_id } map { $_->{id} } $child_cp->get_children() ) {
                        $pairs++;
                        $swaps++;
                    }
                }
            }
        }
    } 

    my $reliable = $pairs >= 4 ? "reliable_" : "rough_";

    if ( $pairs ) {
        $self->add_feature( $bundle, $reliable . "head_swap_ratio="
            . $self->quantize_given_bounds( $swaps / $pairs, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::HeadSwapRatio

=back

A filtering feature. Computes the ratio of nodes with swapped parent-child relation.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

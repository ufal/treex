package Treex::Block::Eval::AtreeUAS;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'eval_is_member' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'eval_is_shared_modifier' => ( is => 'ro', isa => 'Bool', default => 0 );
has sample_size => (
    is => 'ro',
    isa => 'Int',
    default => 0,
    documentation => 'How many sentences should be in a sample (default is 0=all)',
);

my $sentences_in_current_sample = 0;
my $number_of_nodes;
my %same_as_ref;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $ref_zone = $bundle->get_zone( $self->language, $self->selector );
    my @ref_parents = map { $_->get_parent->ord } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    my @ref_is_member = map { $_->is_member ? 1 : 0 } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    my @ref_is_shared_modifier = map { $_->is_shared_modifier ? 1 : 0 } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    my @compared_zones = grep { $_ ne $ref_zone && $_->language eq $self->language } $bundle->get_all_zones();

    $number_of_nodes += @ref_parents;

    foreach my $compared_zone (@compared_zones) {
        my @parents = map { $_->get_parent->ord } $compared_zone->get_atree->get_descendants( { ordered => 1 } );
        my @is_member = map { $_->is_member ? 1 : 0 } $compared_zone->get_atree->get_descendants( { ordered => 1 } );
        my @is_shared_modifier = map { $_->is_shared_modifier ? 1 : 0 } $compared_zone->get_atree->get_descendants( { ordered => 1 } );

        if ( @parents != @ref_parents ) {
            log_fatal 'There must be the same number of nodes in compared trees';
        }
        my $label = $compared_zone->get_label;
        my $label1 = $label.'-regardless-is_member';
        foreach my $i ( 0 .. $#parents ) {

            if ( $parents[$i] == $ref_parents[$i] &&
                 ( !$self->eval_is_member || $is_member[$i] == $ref_is_member[$i] ) &&
                 ( !$self->eval_is_shared_modifier || $is_shared_modifier[$i] == $ref_is_shared_modifier[$i] )
               ) {
                $same_as_ref{$label}++;
            }
            # If the main score includes is_member evaluation, provide the weaker evaluation as well.
            if ( $self->eval_is_member || $self->eval_is_shared_modifier ) {
                if ( $parents[$i] == $ref_parents[$i] ) {
                    $same_as_ref{$label1}++;
                }
            }
        }
    }
    if ($self->sample_size && ++$sentences_in_current_sample >= $self->sample_size){
        print_stats();
    }
    return;
}

sub print_stats {
    foreach my $zone_label ( sort keys %same_as_ref ) {
        print "$zone_label\t$same_as_ref{$zone_label}/$number_of_nodes\t" . ( $same_as_ref{$zone_label} / $number_of_nodes ) . "\n";
    }
    ($sentences_in_current_sample, $number_of_nodes) = (0,0);
    %same_as_ref = ();
    return;
}

END {
    if ($sentences_in_current_sample){
        print_stats();
    }
}

1;

=over

=item Treex::Block::Eval::AtreeUAS

Measure similarity (in terms of unlabeled attachment score) of a-trees in all zones
(of a given language) with respect to the reference zone specified by selector.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, David Marecek, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

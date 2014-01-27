package Treex::Block::Filter::HindenCorp::UnrecognizedTagRatio;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Filter::Generic::Common';

my @bounds = ( 0, 0.2, 0.4, 0.6, 0.8, 1 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    for my $zone ( qw( hi ) ) { # just for Hindi; English analysis never outputs 'unknown'
        my @nodes = $bundle->get_zone( $zone )->get_atree->get_descendants;
        my @pos = map { substr( $_->get_attr( "tag" ), 0, 3 ) } @nodes;
        my $unrecognized = grep { $_ eq 'UNK' } @pos;
        $self->add_feature( $bundle, $zone . "_unrecognized_tag_ratio="
            . $self->quantize_given_bounds( $unrecognized / @nodes, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::HindenCorp::UnrecognizedTagRatio

=back

Ratio of unrecognized tags.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

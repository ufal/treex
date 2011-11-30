package Treex::Block::Filter::CzEng::UnrecognizedTagRatio;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Filter::CzEng::Common';

my @bounds = ( 0, 0.2, 0.4, 0.6, 0.8, 1 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    for my $zone ( qw( cs ) ) { # just for Czech; English analysis never outputs 'unknown'
        my @nodes = $bundle->get_zone( $zone )->get_atree->get_descendants;
        my @pos = map { substr( $_->get_attr( "tag" ), 0, 1 ) } @nodes;
        my $unrecognized = grep { $_ eq 'X' } @pos;
        $self->add_feature( $bundle, $zone . "_unrecognized_tag_ratio="
            . $self->quantize_given_bounds( $unrecognized / @nodes, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::UnrecognizedTagRatio

=back

Ratio of unrecognized tags. Computed separately for English and Czech.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

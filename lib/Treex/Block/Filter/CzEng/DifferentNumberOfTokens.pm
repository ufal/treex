package Treex::Block::Filter::CzEng::DifferentNumberOfTokens;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en = $bundle->get_zone('en')->get_atree->get_descendants;
    my $cs = $bundle->get_zone('cs')->get_atree->get_descendants;

    my $reliable = "";# max($en, $cs) >= 5 ? "reliable_" : "rough_";
    my @bounds = ( 0, 0.4, 0.8, 1.2, 1.6, 2, 4, 10 );

    $self->add_feature( $bundle, $reliable . 'lengthratio=' . $self->quantize_given_bounds( $en / $cs, @bounds ) );

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::DifferentNumberOfTokens

Filtering feature derived from the ratio of the number of tokens
in the two sentences.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

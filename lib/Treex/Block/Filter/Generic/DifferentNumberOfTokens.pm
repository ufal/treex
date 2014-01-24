package Treex::Block::Filter::Generic::DifferentNumberOfTokens;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );
extends 'Treex::Block::Filter::Generic::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $src = $bundle->get_zone($self->language)->get_atree->get_descendants;
    my $tgt = $bundle->get_zone($self->to_language)->get_atree->get_descendants;

    my $reliable = "";# max($en, $cs) >= 5 ? "reliable_" : "rough_";
    my @bounds = ( 0, 0.4, 0.8, 1.2, 1.6, 2, 4, 10 );

    $self->add_feature( $bundle, $reliable . 'lengthratio=' . $self->quantize_given_bounds( $src / $tgt, @bounds ) );

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::DifferentNumberOfTokens

Filtering feature derived from the ratio of the number of tokens
in the two sentences.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

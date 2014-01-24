package Treex::Block::Filter::Generic::LongSentence;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );
extends 'Treex::Block::Filter::Generic::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $src    = $bundle->get_zone($self->language)->sentence;
    my $tgt    = $bundle->get_zone($self->to_language)->sentence;
    my $length = max( length $src, length $tgt );

    my @bounds = ( 0, 10, 50, 100, 250, 500 );
    $self->add_feature( $bundle, 'sentence_length=' . $self->quantize_given_bounds( $length, @bounds ) );

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::LongSentence

Quantized maximum sentence length.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

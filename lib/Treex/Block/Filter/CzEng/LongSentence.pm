package Treex::Block::Filter::CzEng::LongSentence;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en     = $bundle->get_zone('en')->sentence;
    my $cs     = $bundle->get_zone('cs')->sentence;
    my $length = max( length $en, length $cs );

    $self->add_feature( $bundle, 'sentence_length=' . ( int( $length / 50 ) ) * 50 );

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::LongSentence

Quantized maximum sentence length.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::Filter::CzEng::LongWord;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @tokens = ($bundle->get_zone('en')->get_atree->get_descendants,
                  $bundle->get_zone('cs')->get_atree->get_descendants);

    my $length = max( map { length $_->get_attr('form') } @tokens );

    $self->add_feature( $bundle, 'word_length=' . (int( $length / 10 )) * 10 );

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::LongWord

Quantized maximum word length.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

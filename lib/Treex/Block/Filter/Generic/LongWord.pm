package Treex::Block::Filter::Generic::LongWord;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );
extends 'Treex::Block::Filter::Generic::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @tokens = (
        $bundle->get_zone($self->language)->get_atree->get_descendants,
        $bundle->get_zone($self->to_language)->get_atree->get_descendants
    );

    my $length = max( map { length $_->get_attr('form') } @tokens );

    my @bounds = ( 0, 5, 10, 20, 50 );
    $self->add_feature( $bundle, 'max_word_length=' . $self->quantize_given_bounds( $length, @bounds ) );

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::LongWord

Quantized maximum word length.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

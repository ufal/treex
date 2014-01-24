package Treex::Block::Filter::Generic::LetterCount;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
use List::Util qw( min );
extends 'Treex::Block::Filter::Generic::Common';


my @bounds = ( 2, 5, 10 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $src = $bundle->get_zone($self->language)->sentence;
    my $tgt = $bundle->get_zone($self->to_language)->sentence;

    if ( $src !~ /^\s*[0-9]+\s*[\.)]?\s*$/ && $tgt !~ /^\s*[0-9]+\s*[\.)]?\s*$/ ) {
        my $min_letter_count = min( ( $src =~ s/\p{L}//g ), ( $tgt =~ s/\p{L}//g ) );
        $self->add_feature( $bundle, "letter_count="
            . $self->quantize_given_bounds( $min_letter_count, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::LetterCount

Report sentences with small number of characters.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

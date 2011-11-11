package Treex::Block::Filter::CzEng::LetterCount;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
use List::Util qw( min );
extends 'Treex::Block::Filter::CzEng::Common';


my @bounds = ( 2, 5, 10 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en      = $bundle->get_zone('en')->sentence;
    my $cs      = $bundle->get_zone('cs')->sentence;

    if ( $en !~ /^\s*[0-9]+\s*[\.)]?\s*$/ && $cs !~ /^\s*[0-9]+\s*[\.)]?\s*$/ ) {
        my $min_letter_count = min( ( $en =~ s/p{L}//g ), ( $cs =~ s/p{L}//g ) );
        $self->add_feature( $bundle, $self->quantize_given_bounds( $min_letter_count, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::LetterCount

Report sentences with small number of characters.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

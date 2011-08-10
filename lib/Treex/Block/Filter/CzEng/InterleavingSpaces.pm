package Treex::Block::Filter::CzEng::InterleavingSpaces;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en      = $bundle->get_zone('en')->sentence;
    my $cs      = $bundle->get_zone('cs')->sentence;
    my $pattern = ' \w \w \w \w ';
    if ( $cs =~ m/$pattern/ || $en =~ m/$pattern/ ) {
        $self->add_feature( $bundle, 'interleaving_spaces' );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::InterleavingSpaces

Letters interleaved w i t h  s p a c e s.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

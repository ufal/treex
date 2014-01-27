package Treex::Block::Filter::HindenCorp::NonASCIICharacter;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::HindenCorp::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en      = $bundle->get_zone('en')->sentence;
    my $hi      = $bundle->get_zone('hi')->sentence;
    while ($en =~ m/([^\p{ASCII}“”´´``—–€‐‘’‑‑])/g) {
        if ($hi !~ m/$1/) {
            $self->add_feature( $bundle, 'nonascii_character' );
            last;
        }
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::HindenCorp::NonASCIICharacter

English side contains a non-ASCII character not confirmed by the Czech side.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

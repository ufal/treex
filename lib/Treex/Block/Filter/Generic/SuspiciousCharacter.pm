package Treex::Block::Filter::Generic::SuspiciousCharacter;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::Generic::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $src     = $bundle->get_zone($self->language)->sentence;
    my $tgt     = $bundle->get_zone($self->to_language)->sentence;
    my $pattern = '[^ \p{IsAlnum}\p{IsPunct}\$\`°´\+\=\|±€£<>≥≤½§►×]';
    if ( $tgt =~ m/$pattern/ || $src =~ m/$pattern/ ) {
        $self->add_feature( $bundle, 'suspicious_character' );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::SuspiciousCharacter

All characters that are not alphanumeric, punctuation or ' '
(and some others) are suspicious.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

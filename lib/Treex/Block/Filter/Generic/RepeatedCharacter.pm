package Treex::Block::Filter::Generic::RepeatedCharacter;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::Generic::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $src     = $bundle->get_zone($self->language)->sentence;
    my $tgt     = $bundle->get_zone($self->to_language)->sentence;
    my $pattern = '([^\d])\1{3,}';
    if ( $src =~ m/$pattern/ || $tgt =~ m/$pattern/ ) {
        $self->add_feature( $bundle, 'repeated_character' );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::RepeatedCharacter

Finding subsequences of a character repeated four or more times.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

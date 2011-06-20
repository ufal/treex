package Treex::Block::Filter::CzEng::DifferentNumberOfTokens;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en = $bundle->get_zone('en','src')->get_atree->get_descendants;
    my $cs = $bundle->get_zone('cs','tst')->get_atree->get_descendants;

    $self->add_feature( $bundle, ' lengthratio=' . sprintf("%.01f",$en/$cs));

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::DifferentNumberOfTokens

Filtering feature derived from the ratio of the number of tokens
in the two sentences.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

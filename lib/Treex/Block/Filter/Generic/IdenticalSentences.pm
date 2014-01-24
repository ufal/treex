package Treex::Block::Filter::Generic::IdenticalSentences;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::Generic::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $src = $bundle->get_zone($self->language)->sentence;
    my $tgt = $bundle->get_zone($self->to_language)->sentence;

    $self->add_feature( $bundle, 'identical' ) if $src eq $tgt;

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::IdenticalSentences

Feature that fires when cs and en are identical.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

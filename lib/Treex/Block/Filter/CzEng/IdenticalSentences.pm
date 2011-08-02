package Treex::Block::Filter::CzEng::IdenticalSentences;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en = $bundle->get_zone('en')->sentence;
    my $cs = $bundle->get_zone('cs')->sentence;

    $self->add_feature( $bundle, 'identical' ) if $cs eq $en;

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::IdenticalSentences

Feature that fires when cs and en are identical.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

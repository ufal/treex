package Treex::Block::Filter::HindenCorp::InconsistentNumber;
use Moose;
use List::Util qw( sum );

extends 'Treex::Block::Filter::Generic::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @hi = $bundle->get_zone('hi')->get_atree->get_descendants;
   
    my ( $en_has_plural, $hi_has_plural ) = qw( 0 0 );
    $en_has_plural = 1 if grep { $_ =~ m/^N.S/ } map { $_->get_attr("tag") } @en;
    $hi_has_plural = 1 if grep { $_ =~ m/^N(N|ST|NP)\.[^\.]*\.[^\.]*\.pl/ } map { $_->get_attr("tag") } @hi;

    $self->add_feature( $bundle, "inconsistent_gram_number" ) if $en_has_plural != $hi_has_plural;

    return 1;
}

1;

=over

=item Treex::Block::Filter::HindenCorp::InconsistentNumber

=back

Fires if one side contains a word in plural and the other one does not.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

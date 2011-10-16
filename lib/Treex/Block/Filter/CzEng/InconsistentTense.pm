package Treex::Block::Filter::CzEng::InconsistentTense;
use Moose;
use List::Util qw( sum );

extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;
   
    my ( $en_has_past, $cs_has_past ) = qw( 0 0 );
    $en_has_past = 1 if grep { $_ =~ m/^V.D/ } map { $_->get_attr("tag") } @en;
    $cs_has_past = 1 if grep { $_ =~ m/^V.......R/ } map { $_->get_attr("tag") } @cs;

    $self->add_feature( $bundle, "inconsistent_tense_past" ) if $en_has_past != $cs_has_past;

    my ( $en_has_present, $cs_has_present ) = qw( 0 0 );
    $en_has_present = 1 if grep { $_ =~ m/^V.[PZ]?$/ } map { $_->get_attr("tag") } @en;
    $cs_has_present = 1 if grep { $_ =~ m/^V.......P/ } map { $_->get_attr("tag") } @cs;

    $self->add_feature( $bundle, "inconsistent_tense_present" ) if $en_has_present != $cs_has_present;

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::InconsistentTense

=back

Fires if one side contains a verb in present/past and the other does not.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

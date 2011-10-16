package Treex::Block::Filter::CzEng::InconsistentGrade;
use Moose;
use List::Util qw( sum );

extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;
   
    my ( $en_has_comp, $cs_has_comp ) = qw( 0 0 );
    $en_has_comp = 1 if grep { $_ =~ m/^[JR].R/ } map { $_->get_attr("tag") } @en;
    $cs_has_comp = 1 if grep { $_ =~ m/^[AD]........2/ } map { $_->get_attr("tag") } @cs;

    $self->add_feature( $bundle, "inconsistent_grade_comp" ) if $en_has_comp != $cs_has_comp;

    my ( $en_has_super, $cs_has_super ) = qw( 0 0 );
    $en_has_super = 1 if grep { $_ =~ m/^[JR].S/ } map { $_->get_attr("tag") } @en;
    $cs_has_super = 1 if grep { $_ =~ m/^[AD]........3/ } map { $_->get_attr("tag") } @cs;

    $self->add_feature( $bundle, "inconsistent_grade_super" ) if $en_has_super != $cs_has_super;

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::InconsistentGrade

=back

Fires if one side contains a word in comparative/superlative and the other does not.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

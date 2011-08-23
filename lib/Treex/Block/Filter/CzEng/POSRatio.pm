package Treex::Block::Filter::CzEng::POSRatio;
use Moose;
use Treex::Core::Common;
use List::Util qw( sum );

extends 'Treex::Block::Filter::CzEng::Common';

my @watched_en = qw( N V A R );
my %counterparts_cs = (
    N => "N",
    V => "V",
    A => "A",
    R => "D"
);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;
    
    my @en_pos = map { substr($_->get_attr("tag"), 0, 1) } @en;
    my @cs_pos = map { substr($_->get_attr("tag"), 0, 1) } @cs;

    for my $en_pos_tag (@watched_en) {
        my $cs_pos_tag = $counterparts_cs{$en_pos_tag};
        my $en_sum = sum grep { $_ eq $en_pos_tag } @en_pos;
        my $cs_sum = sum grep { $_ eq $cs_pos_tag } @cs_pos;
        $self->add_feature( $bundle, "posratio_$en_pos_tag" . "_$cs_pos_tag="
                            . sprintf( "%.01f", $cs_sum / $en_sum ) );                
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::POSRatio

=back

A filtering feature. Computes the ratio of counts of several parts of speech,
currently nouns, verbs, adjectives and adverbs.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::Filter::CzEng::POSRatio;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );

extends 'Treex::Block::Filter::CzEng::Common';

# watched{en_tag} = cs_tag
my %watched = (
    N => "N",
    V => "V",
    J => "A",
    R => "D"
);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;
    
    my @en_pos = map { substr($_->get_attr("tag"), 0, 1) } @en;
    my @cs_pos = map { substr($_->get_attr("tag"), 0, 1) } @cs;

    for my $en_pos_tag (keys %watched) {
        my $cs_pos_tag = $watched{$en_pos_tag};
        my $en_sum = scalar grep { $_ eq $en_pos_tag } @en_pos;
        my $cs_sum = scalar grep { $_ eq $cs_pos_tag } @cs_pos;
        
        my $reliable = max($en_sum, $cs_sum) >= 4 ? "reliable_" : "rough_";
        my @bounds = ( 0, 0.25, 0.75, 1.25, 1.75, 5 );
        
        my $value;
        if ( $cs_sum ) {
            if ( $en_sum ) {
                $value = $self->quantize_given_bounds( $cs_sum / $en_sum, @bounds );
            } else {
                $value = "inf";
            }
        } elsif ( $en_sum ) {
            $value = 0;
        } else {
            next;
        }

        $self->add_feature( $bundle, $reliable . "posratio_$en_pos_tag" . "_$cs_pos_tag=$value" );
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

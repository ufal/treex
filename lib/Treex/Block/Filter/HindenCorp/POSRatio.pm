package Treex::Block::Filter::HindenCorp::POSRatio;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );

extends 'Treex::Block::Filter::Generic::Common';

# watched{en_tag} = ( hi_tags )
my %watched = (
    N => [ "NN", "NST", "NNP" ],
    V => [ "VM", "VAUX" ],
    J => [ "JJ" ],
    R => [ "RB" ],
);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @hi = $bundle->get_zone('hi')->get_atree->get_descendants;
    
    my @en_pos = map { substr($_->get_attr("tag"), 0, 1) } @en;
    my @hi_pos = map { $_->get_attr("tag") } @hi;

    for my $en_pos_tag (keys %watched) {
        my $hi_pos_regex = '^(' . join('|', @{ $watched{$en_pos_tag} }), ')$';
        my $en_sum = scalar grep { $_ eq $en_pos_tag } @en_pos;
        my $hi_sum = scalar grep { $_ =~ m/$hi_pos_regex/ } @hi_pos;
        
        my $reliable = "";# max($en_sum, $hi_sum) >= 4 ? "reliable_" : "rough_";
        my @bounds = ( 0, 0.25, 0.75, 1.25, 1.75, 5 );
        
        my $value;
        if ( $hi_sum ) {
            if ( $en_sum ) {
                $value = $self->quantize_given_bounds( $hi_sum / $en_sum, @bounds );
            } else {
                $value = "inf";
            }
        } elsif ( $en_sum ) {
            $value = 0;
        } else {
            next;
        }

        $self->add_feature( $bundle, $reliable . "posratio_$en_pos_tag=$value" );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::HindenCorp::POSRatio

=back

A filtering feature. Computes the ratio of counts of several parts of speech,
currently nouns, verbs, adjectives and adverbs.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

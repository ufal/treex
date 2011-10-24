package Treex::Block::Filter::CzEng::AlignmentScore;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );

extends 'Treex::Block::Filter::CzEng::Common';

my @bounds = ( -50, -25, -10, -5, -2, -1 );

sub process_document {
    my ( $self, $document ) = @_;

    for my $bundle ( $document->get_bundles() ) {
        my @en = $bundle->get_zone('en')->get_atree->get_descendants;
        my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;
        my $therescore = $bundle->get_zone('cs')
            ->get_atree->get_attr( "giza_scores/therevalue" );
        next if !defined $therescore;
        my $backscore = $bundle->get_zone('cs')
            ->get_atree->get_attr( "giza_scores/backvalue" );
        next if !defined $therescore;

        my $score = $therescore / @cs + $backscore / @en;
        $self->add_feature( $bundle, "word_alignment_score="
            . $self->quantize_given_bounds( $score, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::AlignmentScore

=back

A filtering feature computed from word alignment score as output by Giza++.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

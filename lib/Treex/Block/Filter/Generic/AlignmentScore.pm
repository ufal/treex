package Treex::Block::Filter::Generic::AlignmentScore;
use Moose;
use Treex::Core::Common;
use List::Util qw( max );

extends 'Treex::Block::Filter::Generic::Common';

my @bounds = ( -50, -25, -10, -5, -2, -1 );
my $ZERO = 1e-300;

sub process_document {
    my ( $self, $document ) = @_;

    for my $bundle ( $document->get_bundles() ) {
        my @src = $bundle->get_zone($self->language)->get_atree->get_descendants;
        my @tgt = $bundle->get_zone($self->to_language)->get_atree->get_descendants;
        my $therescore = $bundle->get_zone($self->language)
            ->get_atree->get_attr( "giza_scores/therevalue" );
        next if ! $therescore; # we don't want 0 in log()
        my $backscore = $bundle->get_zone($self->language)
            ->get_atree->get_attr( "giza_scores/backvalue" );
        next if ! $backscore;

        $therescore = max( $ZERO, $therescore );
        $backscore = max( $ZERO, $backscore );

        my $score = log( $therescore ) / @tgt + log( $backscore ) / @src;
        $self->add_feature( $bundle, "word_alignment_score="
            . $self->quantize_given_bounds( $score, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::AlignmentScore

=back

A filtering feature computed from word alignment score as output by Giza++.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

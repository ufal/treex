package Treex::Block::Filter::Generic::AlignmentCummulation;
use Moose;
use Treex::Core::Common;
use List::Util qw( min max );

extends 'Treex::Block::Filter::Generic::Common';

my @bounds = ( 0, 1, 2, 3, 5, 8, 10, 15 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @src = $bundle->get_zone($self->language)->get_atree->get_descendants( { ordered => 1 } );

    my %tgt2src;
    my %src2tgt;

    my $src_index = -1;

    # over all nodes
    for my $links_ref (map { $_->get_attr( "alignment" ) } @src) {
        $src_index++;
        next if ! $links_ref;

        # over all node links
        for my $link ( @$links_ref ) {
            # only care about points included in GDFA alignment
            my $in_gdfa = grep { $_ eq "gdfa" } split /\./, $link->{"type"};
            next if ! $in_gdfa;

            # get the node index
            my $node_id = $link->{"counterpart.rf"};
            $node_id =~ m/-n(\d+)$/;
            my $tgt_index = $1 - 1; # zero based

            $tgt2src{$tgt_index}++;
            $src2tgt{$src_index}++;
        }
    }

    my $max_cummulation = max( values %tgt2src, values %src2tgt );

    if ( defined $max_cummulation ) {
        $self->add_feature( $bundle, "alignment_cummulation="
            . $self->quantize_given_bounds( $max_cummulation, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::AlignmentCummulation

=back

The maximum of alignment links leading from a word.

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

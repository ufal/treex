package Treex::Block::Filter::CzEng::AlignmentCummulation;
use Moose;
use Treex::Core::Common;
use List::Util qw( min max );

extends 'Treex::Block::Filter::CzEng::Common';

my @bounds = ( 0, 1, 2, 3, 5, 8, 10, 15 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;

    my %cs2en;
    my %en2cs;

    my $cs_index = -1;

    # over all nodes
    for my $links_ref (map { $_->get_attr( "alignment" ) } @cs) {
        $cs_index++;
        next if ! $links_ref;

        # over all node links
        for my $link ( @$links_ref ) {
            # only care about points included in GDFA alignment
            my $in_gdfa = grep { $_ eq "gdfa" } split /\./, $link->{"type"};
            next if ! $in_gdfa;

            # get the node index
            my $node_id = $link->{"counterpart.rf"};
            $node_id =~ m/-n(\d+)$/;
            my $en_index = $1 - 1; # zero based

            $cs2en{$cs_index}++;
            $en2cs{$en_index}++;
        }
    }

    my $max_cummulation = max( values %cs2en, values %en2cs );

    if ( defined $max_cummulation ) {
        $self->add_feature( $bundle, "alignment_cummulation="
            . $self->quantize_given_bounds( $max_cummulation, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::AlignmentCummulation

=back

The maximum of alignment links leading from a word.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

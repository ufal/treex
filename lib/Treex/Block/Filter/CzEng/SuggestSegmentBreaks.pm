package Treex::Block::Filter::CzEng::SuggestSegmentBreaks;
use Moose;
use Treex::Core::Common;

has 'max_size' => (
    is  => 'ro',
    isa => 'Int',
    default => 13,
    required => 1,
);

sub _get_link_counts {
    my ($self, $doc, $type) = @_;
    # type = gram | text | both

    my @link_counts = ();

    my %processed_node_ids = ();
    my @non_visited_ante_ids = ();

    # process nodes in the reversed order
    foreach my $bundle (reverse $doc->get_bundles) {
        # TODO handle selectors and languages
        my ($sel, $lang) = ('src', 'cs');
        my $tree = $bundle->get_tree( $lang, 't', $sel );

        foreach my $node (reverse $tree->get_descendants({ ordered => 1 })) {
            
            # remove links where $node is an antecedent
            @non_visited_ante_ids = grep {$node->id ne $_} @non_visited_ante_ids;

            # get antes
            my @ante_ids = ();
            if ($type eq 'gram') {
                @ante_ids = $node->get_attr('coref_gram.rf');
            }
            elsif ($type eq 'text') {
                @ante_ids = $node->get_attr('coref_text.rf');
            }
            else {
                push @ante_ids, $node->get_attr('coref_gram.rf');
                push @ante_ids, $node->get_attr('coref_text.rf');
            }

            # skip cataphoric links
            my @non_cataph = grep {!defined $processed_node_ids{$_}} @ante_ids;
            push @non_visited_ante_ids, @non_cataph;
            
            $processed_node_ids{ $node->id }++;
        }

        # store the number of links from this tree to previous ones
        unshift @link_counts, scalar @non_visited_ante_ids;
    }
    return @link_counts;
}

sub _get_break_vector {
    my ($self, @link_counts) = @_;

    my @break_idx_list = ();
    
    my $without_break = 0;
    my $min_idx = 0;

    for (my $i = 0; $i < scalar @link_counts; $i++) {
        if ($without_break >= $self->max_size) {
            push @break_idx_list, $min_idx;
            $without_break = $i - $min_idx;
            $min_idx++;
            for (my $j = $min_idx; $j < $i + 1; $j++) {
                if ($link_counts[$j] <= $link_counts[$min_idx]) {
                    $min_idx = $j;
                }
            }
        }
        else {
            if ($link_counts[$i] <= $link_counts[$min_idx]) {
                $min_idx = $i;
            }
            $without_break++;
        }
        if ($link_counts[$i] == 0) {
            $min_idx = $i + 1;
            $without_break = 0;
            push @break_idx_list, $i;
        }
    }
    return @break_idx_list;
}

sub process_document {
    my ( $self, $doc ) = @_;

    # TODO let the user select a type
    my @link_counts = $self->_get_link_counts( $doc, 'all');
    my @break_idx_list = $self->_get_break_vector( @link_counts );

    my @bundles = $doc->get_bundles;
    foreach my $bundle (map {$bundles[$_ + 1]} @break_idx_list) {
        $bundles->wild->{'segm_break'} = 1;
    }
}

1;

=over

=item Treex::Block::Filter::CzEng::SuggestSegmentBreaks

It suggests the places where to split the document into two segments.
The bundle which begins a new segment is labeled with an attribute
wild->{'segm_break'}. These places are selected in the way that the 
number of disconnected coreference links is minimum.
All places which lie between segments that are not interlinked by
coreference relations are labeled as candidates. Intralinked segments
larger than max_size bundles are divided in the place with the smallest
number links.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

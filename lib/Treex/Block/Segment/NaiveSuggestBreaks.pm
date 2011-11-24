package Treex::Block::Segment::NaiveSuggestBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Segment::SuggestSegmentBreaks';


sub _find_breaks {
    my ($self, $scores) = @_;

    my @break_idx_list = ();
    
    # to reduce a rate of segmentation, documents are processed in the reversed order
    # at least at the beginning of a document, the number of interlinks is a non-decreasing sequence of integers
    for (my $i = 0; $i < scalar @$scores; $i++) {
        if ($i % $self->max_size == 0) {
            push @break_idx_list, $i;
        }
    }

    return @break_idx_list;
}

1;

# TODO POD

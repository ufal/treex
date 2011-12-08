package Treex::Block::Segment::GreedyRegSuggestBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Segment::SuggestSegmentBreaks';

has 'regul_param' => (
    is  => 'ro',
    isa => 'Num',
    default => 0.5,
    required => 1,
);

sub _find_breaks {
    my ($self, $scores) = @_;

    my @break_idx_list = ();

    my $sum = 0;
    my $min_avg_diff = undef;
    
    my $without_break = 1;
    my $min_idx = undef;

    # to reduce a rate of segmentation, documents are processed in the reversed order
    # at least at the beginning of a document, the number of interlinks is a non-decreasing sequence of integers
    for (my $i = 1; $i < scalar @$scores; $i++) {

        #print STDERR "$i:$without_break\n";
        
        # find and set a break if the size of the segment exceedes the maximum size
        if ($without_break > $self->max_size) {
            push @break_idx_list, $min_idx;
            $sum = $scores->[$min_idx];
            $min_avg_diff = undef;
            $without_break = 1;
            for (my $j = $min_idx + 1; $j <= $i; $j++) {
                $without_break++;
                $sum += $scores->[$j];
                #my $curr_avg_diff = $scores->[$j] - ($sum / $without_break);
                my $curr_avg_diff = $scores->[$j] - ($sum / $without_break) + $self->regul_param * ($self->max_size - $without_break);
                #if (!defined $min_avg_diff || ($curr_avg_diff <= $min_avg_diff)) {
                if (($curr_avg_diff < 0) && (!defined $min_avg_diff || ($curr_avg_diff < $min_avg_diff))) {
                    $min_avg_diff = $curr_avg_diff;
                    $min_idx = $j;
                }
                if (!defined $min_avg_diff) {
                    $min_idx = $j;
                }
            }
        }
        else {
            $without_break++;
            $sum += $scores->[$i];
            #my $curr_avg_diff = $scores->[$i] - ($sum / $without_break);
            my $curr_avg_diff = $scores->[$i] - ($sum / $without_break) + $self->regul_param * ($self->max_size - $without_break);
            # cut a longer continuous segment in the last place with the minimum score
    #        if (!defined $min_avg_diff || ($curr_avg_diff <= $min_avg_diff)) {
            if (($curr_avg_diff < 0) && (!defined $min_avg_diff || ($curr_avg_diff < $min_avg_diff))) {
                $min_avg_diff = $curr_avg_diff;
                $min_idx = $i;
            }
            if (!defined $min_avg_diff) {
                $min_idx = $i;
            }
        }
        # always set a break if the segments are not interlinked
        #if ($self->_link_count($interlinks[$i]) == 0) {
        #    $min_idx = $i + 1;
        #    $without_break = 0;
        #    push @break_idx_list, $i;
        #}
    }
    # find and set a break if the size of the segment exceedes the maximum size
    if ($without_break > $self->max_size) {
        push @break_idx_list, $min_idx;
    }

    return @break_idx_list;
}

sub name {
    return 'greedy_';
}

1;

# TODO POD

package Treex::Block::Segment::RandomizedSuggestBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Segment::SuggestSegmentBreaks';

has 'local_offset' => ( is => 'ro', isa => 'Int', default => 2, required => 1 );

# JUST FOR DEBUGGING REASONS
#has 'doc_no' => ( is => 'rw', isa => 'Int', default => 0);

#before 'process_document' => sub {
#    my ($self, $doc) = @_;
#    srand($self->doc_no);
#    $self->set_doc_no( $self->doc_no + 1 );
#};

sub _find_breaks {
    my ($self, $scores) = @_;

    # initialize regularly
    my @break_idx_list = grep {$_ % $self->max_size == 0} (1 .. @$scores-1);

    my $max_iter = ($self->max_size / 2) * @break_idx_list;

    #print STDERR "MAX_ITER: $max_iter\n";

    my $i = 0;
    while ($i < $max_iter) {
        
        my $idx = int(rand @break_idx_list);
        my $rand_break_idx = $break_idx_list[$idx];

        my $min_idx = $rand_break_idx;
        for (my $j = -$self->local_offset; $j < $self->local_offset + 1; $j++) {
            if (defined $scores->[$rand_break_idx + $j] && 
                ($scores->[$rand_break_idx + $j] < $scores->[$min_idx])) {
                $min_idx = $rand_break_idx + $j;
            }
        }
        $break_idx_list[$idx] = $min_idx;
        $i++;
    }

    # in order to gain a unique items
    my %hash = map {$_ => 1} @break_idx_list;

    @break_idx_list = sort {$a <=> $b} (keys %hash);

    for (my $i = 1; $i < @break_idx_list; $i++) {
        my $diff = $break_idx_list[$i] - $break_idx_list[$i -1];
        #print STDERR "SEGM_LENGTH: $diff\n";
    }

    return @break_idx_list;
}

sub name {
    return 'randomized_';
}

1;

# TODO POD


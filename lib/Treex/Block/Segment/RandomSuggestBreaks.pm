package Treex::Block::Segment::RandomSuggestBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Segment::SuggestSegmentBreaks';

has 'min_size' => ( is => 'ro', isa => 'Int', default => 13, required => 1 );

sub _find_breaks {
    my ($self, $scores) = @_;

    my @break_idx_list = ();

    my $next_break = 0;
    
    for (my $i = 0; $i < scalar @$scores; $i++) {
        if ($i == $next_break) {
            push @break_idx_list, $i;
            $next_break += $self->min_size + int(rand($self->max_size - $self->min_size + 1));
        }
    }

    return @break_idx_list;
}

1;

=over

=item Treex::Block::Segment::RandomSuggestBreaks

Sets the breaks where contiguous discourse must be split into two separate
segments at random. Used for testing purposes during development of CzEng 1.0.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.


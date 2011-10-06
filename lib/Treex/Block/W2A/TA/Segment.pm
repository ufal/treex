package Treex::Block::W2A::TA::Segment;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::Segment';

has segmenter => (
    is         => 'ro',
    handles    => [qw(get_segments)],
    lazy_build => 1,
);

use Treex::Tool::Segment::TA::RuleBased;

sub _build_segmenter {
    my $self = shift;
    return Treex::Tool::Segment::TA::RuleBased->new(
        use_paragraphs => $self->use_paragraphs,
        use_lines      => $self->use_lines
    );
}

1;

__END__

=over

=item Treex::Block::W2A::EN::Segment

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a English specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

See L<Treex::Block::W2A::Segment>

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

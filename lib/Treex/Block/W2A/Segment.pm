package Treex::Block::W2A::Segment;
use utf8;
use Moose;
use Treex::Common;
extends 'Treex::Block::W2A::SegmentOnNewlines';

has use_paragraphs => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
    documentation =>
        'Should paragraph boundaries be preserved as sentence boundaries?'
        . ' Paragraph boundary is defined as two or more consecutive newlines.',
);

has use_lines => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
    documentation =>
        'Should newlines in the text be preserved as sentence boundaries?'
        . '(But if you want to detect sentence boundaries just based on newlines'
        . ' and nothing else, use rather W2A::SegmentOnNewlines.)',
);

has segmenter => (
    is         => 'ro',
    handles    => [qw(get_segments)],
    lazy_build => 1,
);

use Treex::Tools::Segment::RuleBased;

sub _build_segmenter {
    my $self = shift;
    return Treex::Tools::Segment::RuleBased->new(
        use_paragraphs => $self->use_paragraphs,
        use_lines      => $self->use_lines
    );
}

1;

__END__

=over

=item Treex::Block::W2A::Segment

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class is implemented in a pseudo language-independent way,
but it can be used as an ancestor for language-specific segmentation
by overriding the method C<segment_text>
(using C<around> see L<Moose::Manual::MethodModifiers>)
or just by overriding methods C<unbrekers>, C<openings> and C<closings>.

See L<Treex::Block::W2A::EN::Segment>

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

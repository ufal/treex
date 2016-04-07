package Treex::Block::W2A::Segment;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
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

has limit_words => (
    is      => 'ro',
    isa     => 'Int',
    default => 250,
    documentation =>
        'Should very long segments (longer than the given number of words) be split?'
        . 'The number of words is only approximate; detected by counting whitespace only,'
        . 'not by full tokenization. Set to zero to disable this function completely.',
);

has detect_lists => (
    is      => 'ro',
    isa     => 'Int',
    default => 100,
    documentation =>
        'Minimum (approx.) number of words to toggle list detection, 0 = never, 1 = always.'
);

has segmenter => (
    is         => 'ro',
    handles    => [qw(get_segments)],
    lazy_build => 1,
);

use Treex::Tool::Segment::RuleBased;

sub _build_segmenter {
    my $self = shift;
    return Treex::Tool::Segment::RuleBased->new(
        use_paragraphs => $self->use_paragraphs,
        use_lines      => $self->use_lines,
        limit_words    => $self->limit_words,
        detect_lists   => $self->detect_lists,
    );
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::Segment - rule based segmentation to sentences

=head1 SYNOPSIS

 # in scenario
 W2A::Segment use_paragraphs=1 use_lines=0

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by an uppercase letter.
This class is implemented in a pseudo language-independent way,
but it can be used as a base class for language-specific segmentation
by overriding the method C<get_segments>
(using C<around> see L<Moose::Manual::MethodModifiers>).
The actual implementation is delegated to L<Treex::Tool::Segment::RuleBased>.

=head1 ATTRIBUTES

=head2 use_paragraphs

Should paragraph boundaries be preserved as sentence boundaries?
Paragraph boundary is defined as two or more consecutive newlines.

=head2 use_lines

Should newlines in the text be preserved as sentence boundaries?
However, if you want to detect sentence boundaries just based on newlines
and nothing else, use rather
L<W2A::SegmentOnNewlines|Treex::Block::W2A::SegmentOnNewlines>.

=head2 limit_words

Should very long segments (longer than the given number of words) be split?
The number of words is only approximate; detected by counting whitespace only,
not by full tokenization. Set to zero to disable this function completely (default
is 250 as longer sentences often cause the parser to fail).

=head2 detect_lists

Minimum number of words on a line to toggle list detection rules, 0 = never, 1 = always
(default: 100). The number of words is detected by counting whitespace only.

=head1 SEE ALSO

L<Treex::Tool::Segment::RuleBased>

L<Treex::Block::W2A::EN::Segment>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

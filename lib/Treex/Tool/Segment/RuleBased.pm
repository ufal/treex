package Treex::Tool::Segment::RuleBased;
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

# Tokens that usually do not end a sentence even if they are followed by a period and a capital letter:
# * single uppercase letters serve usually as first name initials
# * in langauge-specific descendants consider adding
#   * period-ending items that never indicate sentence breaks
#   * titles before names of persons etc.
#
# Note, that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{\p{Upper}};

sub unbreakers {
    return $UNBREAKERS;
}

# Characters that can appear after period (or other end-sentence symbol)
sub closings {
    return '"”»)';
}

# Characters that can appear before the first word of a sentence
sub openings {
    return '"“«(';
}

sub get_segments {
    my ( $self, $text ) = @_;

    # Pre-processing
    my $unbreakers = $self->unbreakers;
    $text =~ s/\b($unbreakers)\./$1<<<DOT>>>/g;

    # two newlines usually separate paragraphs
    if ( $self->use_paragraphs ) {
        $text =~ s/([^.!?])\n\n+/$1<<<SEP>>>/gsm;
    }

    if ( $self->use_lines ) {
        $text =~ s/\n/<<<SEP>>>/gsm;
    }

    # Normalize whitespaces
    $text =~ s/\s+/ /gsm;

    # This is the main regex
    my ( $openings, $closings ) = ( $self->openings, $self->closings );
    $text =~ s{
        ([.?!])            # $1 = end-sentence punctuation
        ([$closings]?)          # $2 = optional closing quote/bracket
        \s                 #      space
        ([$openings]?\p{Upper}) # $3 = uppercase letter (optionally preceded by opening quote)
    }{$1$2\n$3}gsxm;

    # Post-processing
    $text =~ s/<<<SEP>>>/\n/gsmx;
    $text =~ s/<<<DOT>>>/./gsxm;
    $text =~ s/\s+$//gsxm;
    $text =~ s/^\s+//gsxm;

    return split /\n/, $text;
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

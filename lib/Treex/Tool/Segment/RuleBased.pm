package Treex::Tool::Segment::RuleBased;
use utf8;
use Moose;
use Treex::Core::Common;

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

    # This is the main work
    $text = $self->split_at_terminal_punctuation($text);

    # Post-processing
    $text =~ s/<<<SEP>>>/\n/gsmx;
    $text =~ s/<<<DOT>>>/./gsxm;
    $text =~ s/\s+$//gsxm;
    $text =~ s/^\s+//gsxm;

    return split /\n/, $text;
}

sub split_at_terminal_punctuation {
    my ( $self, $text ) = @_;
    my ( $openings, $closings ) = ( $self->openings, $self->closings );
    $text =~ s{
        ([.?!])                 # $1 = end-sentence punctuation
        ([$closings]?)          # $2 = optional closing quote/bracket
        \s                      #      space
        ([$openings]?\p{Upper}) # $3 = uppercase letter (optionally preceded by opening quote)
    }{$1$2\n$3}gsxm;
    return $text;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Segment::RuleBased - Rule based pseudo language-independent sentence segmenter

=head1 VERSION

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class is implemented in a pseudo language-independent way,
but it can be used as an ancestor for language-specific segmentation
by overriding the method C<segment_text>
(using C<around> see L<Moose::Manual::MethodModifiers>)
or just by overriding methods C<unbreakers>, C<openings> and C<closings>.

See L<Treex::Block::W2A::EN::Segment>

=head1 METHODS

=over 4

=item get_segments

Returns list of sentences

=back

=head1 METHODS TO OVERRIDE

=over 4

=item segment_text

Do the segmentation (handling C<use_paragraphs> and C<use_lines>)

=item $text = split_at_terminal_punctuation($text)

Adds newlines after terminal punctuation followed by an uppercase letter. 

=item unbreakers

Returns regex that should match tokens that usually do not end a sentence even if they are followed by a period and a capital letter:
* single uppercase letters serve usually as first name initials
* in langauge-specific descendants consider adding
  * period-ending items that never indicate sentence breaks
  * titles before names of persons etc.

=item openings

Returns string with characters that can appear before the first word of a sentence

=item closings

Returns string with characters that can appear after period (or other end-sentence symbol)

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


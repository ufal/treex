package Treex::Tool::Segment::RuleBased;

use strict;
use warnings;
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

# Contextual rules for "un-breaking" (to be overridden)
sub apply_contextual_rules {
    my ($self, $text) = @_;
    return $text;
}

sub get_segments {
    my ( $self, $text ) = @_;

    # Pre-processing
    $text = $self->apply_contextual_rules($text);

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

    # try to separate various list items (e.g. TV programmes, calendars)
    my @segs = map { $self->split_at_list_items($_) } split /\n/, $text;

    # handle segments that are too long
    return map { $self->segment_too_long($_) ? $self->handle_long_segment($_) : $_ } @segs;
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

sub handle_long_segment {
    my ( $self, $seg ) = @_;

    # split at some other dividing punctuation characters (poems, unending speech)
    my @split = map { $self->segment_too_long($_) ? $self->split_at_dividing_punctuation($_) : $_ } $seg;

    # split at any punctuation
    @split = map { $self->segment_too_long($_) ? $self->split_at_any_punctuation($_) : $_ } @split;

    # split hard if still too long
    return map { $self->segment_too_long($_) ? $self->split_hard($_) : $_ } @split;
}

# Return 1 if the segment is too long
sub segment_too_long {
    my ( $self, $seg ) = @_;

    # skip everything if the limit is infinity
    return 0 if ( $self->limit_words == 0 );

    # return 1 if the number of space-separated segments exceeds the limit
    my $wc = () = $seg =~ m/\s+/g;
    return 1 if ( $wc >= $self->limit_words );
    return 0;
}

# "Non-final" punctuation that could divide segments (NB: single dot excluded due to abbreviations)
my $DIV_PUNCT = qr{(!|\.\.+|\?|\*|[–—-](\s*[–—-])+|;)};

sub split_at_dividing_punctuation {
    my ( $self, $text ) = @_;

    my $closings = $self->closings;
    $text =~ s/($DIV_PUNCT\s*[$closings]?,?)/$1\n/g;

    return split /\n/, $self->_join_too_short_segments($text);
}

# Universal list types (currently only semicolon-separated lists, to be overridden in language-specific blocks)
my $LIST_TYPES = [
    {
        name    => ';',       # a label for the list type (just for debugging)
        sep     => ';\h+',    # separator regexp
        sel_sep => undef,     # separator regexp used only for the selection of this list (sep used if not set)
        type    => 'e',       # type of separator (ending: e / staring: s)
        max     => 400,       # maximum average list-item length (overrides the default)
        min     => 30,        # minimum average list-item length (overrides the default)
        # negative pre-context, not used if not set (here: skip semicolons separating just numbers)
        neg_pre => '[0-9]\h*(?=;\h*[0-9]+(?:[^\.0-9]|\.[0-9]|$))',
    },
];

# Language-specific blocks should override this method and provide usual list types for the given language
sub list_types {
    return @{$LIST_TYPES};
}

my $MAX_AVG_ITEM_LEN = 400;    # default maximum average list item length, in characters
my $MIN_AVG_ITEM_LEN = 30;     # default minimum average list item length, in characters
my $MIN_LIST_ITEMS   = 3;      # minimum number of items in a list
my $PRIORITY         = 2.5;    # multiple of list items a lower-rank list type must have over a higher-rank type

sub split_at_list_items {

    my ( $self, $text ) = @_;

    # skip this if list detection is turned off
    return $text if ( $self->detect_lists == 0 );

    # skip too short lines
    my $wc = () = $text =~ m/\s+/g;
    return $text if ( $self->detect_lists > $wc );

    my @list_types = $self->list_types;
    my $sel_list_type;
    my $sel_len;

    # find out which list type is the best for the given text
    for ( my $i = 0; $i < @list_types; ++$i ) {

        my $cur_list_type = $list_types[$i];
        my $sep           = $cur_list_type->{sel_sep} || $cur_list_type->{sep};
        my $neg           = $cur_list_type->{neg_pre};
        my $min           = $cur_list_type->{min} || $MIN_AVG_ITEM_LEN;
        my $max           = $cur_list_type->{max} || $MAX_AVG_ITEM_LEN;

        my $items = () = $text =~ m/$sep/gi;

        # count number of items; exclude negative pre-context matches, if negative pre-context is specified
        my $false = 0;
        $false = () = $text =~ m/$neg(?=$sep)/gi if ($neg);
        $items -= $false;

        my $len = $items > 0 ? ( length($text) / $items ) : 'NaN';

        # test if this type overrides the previously set one
        if ( $items >= $MIN_LIST_ITEMS && $len < $max && $len > $min && ( !$sel_len || $len * $PRIORITY < $sel_len ) ) {
            $sel_list_type = $cur_list_type;
            $sel_len       = $len;
        }
    }

    # return if no list type found
    return $text if ( !$sel_list_type );

    # list type detected, split by the given list type
    my $sep  = $sel_list_type->{sep};
    my $neg  = $sel_list_type->{neg_pre};
    my $name = $sel_list_type->{name};

    # protect negative pre-context, if any is specified
    $text =~ s/($neg)(?=$sep)/$1<<<NEG>>>/gi if ($neg);

    # split at the given list type
    if ( $sel_list_type->{type} eq 'e' ) {
        $text =~ s/(?<!<<<NEG>>>)($sep)/$1\n/gi;
    }
    else {
        $text =~ s/(?<!<<<NEG>>>)($sep)/\n$1/gi;
    }

    # remove negative pre-context protection
    $text =~ s/<<<NEG>>>//g;

    # delete too short splits
    $text = $self->_join_too_short_segments($text);

    # return the split result
    return split /\n/, $text;
}

sub _join_too_short_segments {
    my ( $self, $text ) = @_;

    $text =~ s/^\n//;
    $text =~ s/\n$//;
    $text =~ s/\n(?=\h*(\S+(\h+\S+){0,2})?\h*(\n|$))/ /g;
    return $text;
}

sub split_at_any_punctuation {
    my ( $self, $text ) = @_;

    my $closings = $self->closings;

    # prefer punctuation followed by a letter
    $text =~ s/([,;!?–—-]+\s*[$closings]?)\s+(\p{Alpha})/$1\n$2/g;

    # delete too short splits
    $text = $self->_join_too_short_segments($text);

    my @split = split /\n/, $text;

    # split at any punctuation if the text is still too long
    return map {
        $_ =~ s/([,;!?–—-]+\s*[$closings]?)/$1\n/g if ( $self->segment_too_long($_) );
        split /\n/, $self->_join_too_short_segments($_)
    } @split;
}

sub split_hard {
    my ( $self, $text ) = @_;

    my @tokens = split /(\s+)/, $text;
    my @result;
    my $pos = 0;

    while ( $pos < @tokens ) {
        my $limit = $pos + $self->limit_words * 2 - 1;
        $limit = @tokens - 1 if ( $limit > @tokens - 1 );
        push @result, join( '', @tokens[ $pos .. $limit ] );
        $pos = $limit + 1;
    }
    return @result;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Segment::RuleBased - Rule based pseudo language-independent sentence segmenter

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

=item $text = apply_contextual_rules($text)

Add unbreakers (C<E<lt>E<lt>E<lt>DOTE<gt>E<gt>E<gt>>) and hard breaks (C<\n>) using the whole context, not
just a single word.

=item unbreakers

Returns regex that should match tokens that usually do not end a sentence even if they are followed by a period and a capital letter:
* single uppercase letters serve usually as first name initials
* in language-specific descendants consider adding:
  * period-ending items that never indicate sentence breaks
  * titles before names of persons etc.

=item openings

Returns string with characters that can appear before the first word of a sentence

=item closings

Returns string with characters that can appear after period (or other end-sentence symbol)

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


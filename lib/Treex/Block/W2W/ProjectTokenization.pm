package Treex::Block::W2W::ProjectTokenization;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Depfix::CS::DiacriticsStripper;
use Treex::Tool::Depfix::CS::FixLogger;

has 'source_language' => ( is => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is => 'rw', isa => 'Str', default  => '' );
has 'log_to_console'  => ( is       => 'rw', isa => 'Bool', default => 1 );

my $boundary = '[ \.\/:,;!\?<>\{\}\[\]\(\)\#\$£\%\&`\'‘"“”«»„\*\^\|\+]+';

my $fixLogger;

sub process_start {
    my $self = shift;
    
    $fixLogger = Treex::Tool::Depfix::CS::FixLogger->new({
        language => $self->language,
        log_to_console => $self->log_to_console
    });

    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $sentence    = $zone->sentence;
    my $outsentence = $sentence;
    my $aligned_sentence =
        $zone->get_bundle->get_zone(
        $self->source_language,
        $self->source_selector
        )->sentence;

    my $al_lc_strip =
        Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
            lc $aligned_sentence
        );

    my @tokens = split /$boundary/, $sentence;

    for ( my $i = 0; $i < scalar(@tokens) - 1; $i++ ) {
        next if ( $tokens[$i] eq '' || $tokens[ $i + 1 ] eq '' );

        my $orig_tok = $tokens[$i] . ' ' . $tokens[ $i + 1 ];
        my $new_tok  = $tokens[$i] . $tokens[ $i + 1 ];
        my $n_lc_strip =
            Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
                lc $new_tok
            );

        if ( $outsentence =~ /$orig_tok/i ) {

            # exact match has highest priority
            if ( $aligned_sentence =~ /\b($new_tok)\b/ ) {
                $outsentence =~ s/$orig_tok/$new_tok/i;
                $fixLogger->logfixBundle(
                    $zone->get_bundle,
                    "Retokenizing '$orig_tok' -> '$new_tok'"
                );
            }

            # case-insensitive match: also adopt the casing
            elsif ( $aligned_sentence =~ /\b($new_tok)\b/i ) {
                my $new = $1;
                $outsentence =~ s/$orig_tok/$new/i;
                $fixLogger->logfixBundle(
                    $zone->get_bundle,
                    "Retokenizing '$orig_tok' -> '$new'"
                );
            }

            # diacritics-insensitive match
            elsif ( $al_lc_strip =~ /\b($n_lc_strip)\b/ ) {
                $outsentence =~ s/$orig_tok/$new_tok/i;
                $fixLogger->logfixBundle(
                    $zone->get_bundle,
                    "Retokenizing '$orig_tok' -> '$new_tok' ($n_lc_strip)"
                );
            }
        }

    }
    
    $outsentence =~ s/([0-9])(st|nd|rd|th)\b/$1./ig;

    $zone->set_sentence($outsentence);
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::ProjectTokenization
- retokenize the sentence using its aligned sentence 

=head1 DESCRIPTION

Retokenize the sentence where it "nearly matches" its aligned sentence.
Intended to be used on Bojar's Moses output to fix stuff such as
"on - line" -> "on-line",
"al - Somali" -> "al-Somali",
"Jean - Marie" -> "Jean-Marie"

Removes superfluous whitespace
if the forms otherwise match
-- at least case-insensitively and at least without diacritics.
The casing is also fixed if this is straight-forward.

The regex used for (coarse) token splitting
is based on L<Treex::Block::W2A::Tokenize>.

Caveats: it is very simple so it has occasional false-positives, such as
en: "the diploma and the money",
cs: "diplom a peníze"
becomes
cs: "diploma peníze".
However, such cases are very rare (and could be fixed by adding some more rules,
such as "don't fix if both tokens consist only of letters").

Also, it "fixes" things that actually should be tokenized differently,
such as units (en: "300m" but cs: "300 m").
A clever language-specific detokenizer should be used to fix that.

Also, it is stricter when searching than when replacing and thus can replace a
different, earlier match than the intended one. This is clearly a bug,
but it is very rare so I haven't looked into that yet...
Example of the bug:
cs: "Mám 2 m 2 látky.",
en: "I have 2 m2 of cloth.",
tries to replace "m 2 -> m2",
but the result is "Mám2 m2 látky."

As a "bonus", the block also fixes ordinal numerals (which probably should be
moved to a separate block): 1st -> 1., 456th -> 456. etc.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

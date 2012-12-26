package Treex::Block::W2W::ProjectTokenization;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Depfix::CS::DiacriticsStripper;

has 'source_language' => ( is => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is => 'rw', isa => 'Str', default  => '' );

my $boundary = '[ \.\/:,;!\?<>\{\}\[\]\(\)\#\$£\%\&`\'‘"“”«»„\*\^\|\+]+';

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

        # boundary before and after $new_tok
        # (if there already is a "natural" boundary,
        #  do not require another one)
        my $b1 = $boundary;
        if ( $i == 0 || $tokens[$i] !~ /\w/ ) {
            $b1 = '';
        }
        my $b2 = $boundary;
        if ( ( $i + 1 == @tokens ) || $tokens[ $i + 1 ] !~ /\w/ ) {
            $b2 = '';
        }

        if ( $outsentence =~ /$orig_tok/i ) {

            # exact match has highest priority
            if ( $aligned_sentence =~ /$b1($new_tok)$b2/ ) {
                $outsentence =~ s/$orig_tok/$new_tok/i;
                log_info "Retokenizing '$orig_tok' -> '$new_tok'";
            }

            # case-insensitive match: also adopt the casing
            elsif ( $aligned_sentence =~ /$b1($new_tok)$b2/i ) {
                my $new = $1;
                $outsentence =~ s/$orig_tok/$new/i;
                log_info "Retokenizing '$orig_tok' -> '$new'";
            }

            # diacritics-insensitive match
            elsif ( $al_lc_strip =~ /$b1($n_lc_strip)$b2/ ) {
                $outsentence =~ s/$orig_tok/$new_tok/i;
                log_info "Retokenizing '$orig_tok' -> '$new_tok' ($n_lc_strip)";
            }
        }

    }

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

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

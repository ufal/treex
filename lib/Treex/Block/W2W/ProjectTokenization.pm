package Treex::Block::W2W::ProjectTokenization;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Depfix::CS::DiacriticsStripper;

has 'source_language' => ( is => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is => 'rw', isa => 'Str', default  => '' );

sub process_zone {
    my ( $self, $zone ) = @_;

    my $sentence    = $zone->sentence;
    my $outsentence = $sentence;
    my $aligned_sentence =
      $zone->get_bundle->get_zone( $self->source_language,
        $self->source_selector )->sentence;

    my $al_lc_strip =
        Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
            lc $aligned_sentence);

    my @tokens =
      split
      /[ \.\/:,;!\?<>\{\}\[\]\(\)\#\$£\%\&`\'‘"“”«»„\*\^\|\+]+/,
      $sentence;

    # try to find a hyphen everywhere
    # but the very beginning and end of the sentence
    for ( my $i = 1 ; $i < scalar(@tokens) - 1 ; $i++ ) {
        if ( $tokens[$i] eq '-' ) {
            my $orig_tok = $tokens[ $i - 1 ] . ' - ' . $tokens[ $i + 1 ];
            my $new_tok  = $tokens[ $i - 1 ] . '-' . $tokens[ $i + 1 ];
            my $n_lc_strip = 
                Treex::Tool::Depfix::CS::DiacriticsStripper::strip_diacritics(
                    lc $new_tok);
            if ( $outsentence =~ /$orig_tok/i ) {
                if ($aligned_sentence =~ /$new_tok/ ) {
                    $outsentence =~ s/$orig_tok/$new_tok/i;
                    log_info "Retokenizing '$orig_tok' -> '$new_tok'";
                }
                elsif ( $aligned_sentence =~ /($new_tok)/i ) {
                    my $new = $1;
                    $outsentence =~ s/$orig_tok/$new/i;
                    log_info "Retokenizing '$orig_tok' -> '$new'";                    
                }
                elsif ( $al_lc_strip =~ /$n_lc_strip/ ) {
                    $outsentence =~ s/$orig_tok/$new_tok/i;
                    log_info "Retokenizing '$orig_tok' -> '$new_tok' ($n_lc_strip)";
                }
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

Removes superfluous whitespace around a dash
if the forms otherwise match
-- at least case-insensitively and at least without diacritics.
The casing is also fixed if this is straight-forward.
(There can be special characters around (brackets, quotes etc.),
but it is assumed that there are no special characters inside,
i.e. around the hyphen.)

The regex used for (coarse) token splitting
is based on L<Treex::Block::W2A::Tokenize>.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

package Treex::Block::W2W::ProjectTokenization;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'source_language' => ( is => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is => 'rw', isa => 'Str', default  => '' );

sub process_zone {
    my ( $self, $zone ) = @_;

    my $sentence    = $zone->sentence;
    my $outsentence = $sentence;
    my $aligned_sentence =
      $zone->get_bundle->get_zone( $self->source_language,
        $self->source_selector )->sentence;

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
            if (   $outsentence =~ /$orig_tok/
                && $aligned_sentence =~ /$new_tok/ )
            {
                $outsentence =~ s/$orig_tok/$new_tok/;
                log_info "Retokenizing '$orig_tok' -> '$new_tok'";
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

In the current version only removes superfluous whitespace around a dash
if the forms otherwise match exactly.
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

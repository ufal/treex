package Treex::Tool::DerivMorpho::Block::CS::AddDerivationsFromLemmaSuffices;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Tool::Lexicon::CS;

sub process_dictionary {

    my ($self, $dict) = @_;

    foreach my $lexeme ( grep {not $_->source_lexeme} $dict->get_lexemes ) { # TODO: add an option for overriding?

        $lexeme->mlemma =~ /\^\(\*(\d)(.*)\)/ or next;
        my ( $lenght_of_old_suffix, $new_suffix ) = ($1, $2);

        my $new_mlemma = $lexeme->mlemma;
        $new_mlemma =~ s/_.+//;
        $new_mlemma =~ s/.{$lenght_of_old_suffix}$/$new_suffix/;
        if ($new_mlemma eq $lexeme->mlemma) {
            print "These two should not be equal\n";
        }

        my $short_new_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($new_mlemma);

        my ($source_lexeme) = $dict->get_lexemes_by_lemma($short_new_lemma);
        if ($source_lexeme) {
            $dict->add_derivation({
                source_lexeme => $source_lexeme,
                derived_lexeme => $lexeme,
                deriv_type => $source_lexeme->pos."2".$lexeme->pos,
                derivation_creator => $self->signature,
            });
        }
        else {
            # TODO: doresit generovani (na POS ale potreba analyza)
        }
    }

    return $dict;
}




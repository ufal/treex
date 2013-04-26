package Treex::Tool::DerivMorpho::Block::CS::Prefixes;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

use utf8;

sub process_dictionary {

    my ($self, $dict) = @_;

    foreach my $lexeme ( grep {not $_->source_lexeme} $dict->get_lexemes ) {

        if ($lexeme->lemma =~ /^(pseudo|mikro|anti|dys|meta|super|pra)(.+)/) {
            my $deprefixed_lemma = $2;
            next if $lexeme->lemma =~ /^(prach|pracák|prahnout|pralinka|prase|praskot|pravice|metadon)$/;

            my ($source_lexeme) = grep {$_->pos eq $lexeme->pos} $dict->get_lexemes_by_lemma($deprefixed_lemma);

            if ($source_lexeme) {
#                print $source_lexeme->lemma ." --> ".$lexeme->lemma."\n";
                $dict->add_derivation({
                    source_lexeme => $source_lexeme,
                    derived_lexeme => $lexeme,
                    deriv_type => $source_lexeme->pos."2".$lexeme->pos,
                    derivation_creator => $self->signature,
                });
            }
        }
    }

    return $dict;
}


1;

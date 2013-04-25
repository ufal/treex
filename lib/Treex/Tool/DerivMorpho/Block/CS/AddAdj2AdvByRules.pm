package Treex::Tool::DerivMorpho::Block::CS::AddAdj2AdvByRules;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Tool::Lexicon::CS;
use CzechMorpho;
use utf8;

use Treex::Tool::Lexicon::DerivDict::Dictionary;
use Treex::Tool::Lexicon::CS;

use CzechMorpho;
my $analyzer = CzechMorpho::Analyzer->new();

sub process_lexeme {

    my ($self, $adv_lexeme, $dict) = @_;
    return if $adv_lexeme->pos ne 'D' or $adv_lexeme->lemma !~ /ě$/;

    my $adv_lemma = $adv_lexeme->lemma;
    my @candidates = map {my $lemma = $adv_lemma; $lemma =~ s/ě$/$_/;$lemma} qw(í ý);

    my @long_lemmas;
    foreach my $candidate (@candidates) {
        push @long_lemmas,  map { $_->{lemma} } grep {  $_->{tag} =~ /^AAMS1/ } $analyzer->analyze($candidate);
    }

#    print scalar(@long_lemmas)."\t".$adv_lemma."\t".(join ' ',@long_lemmas)."\n";

    if (@long_lemmas) {

        my $adj_long_lemma = $long_lemmas[0]; # TODO: vyjimecne neni spravny ten prvni, chtelo by to seznam vyjimek
        my $adj_short_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($adj_long_lemma);

        my @adj_lexemes = $dict->get_lexemes_by_lemma($adj_short_lemma);

        if (not @adj_lexemes) {
            push @adj_lexemes,
                $dict->create_lexeme({
                    lemma  => $adj_short_lemma,
                    mlemma => $adj_long_lemma,
                    pos => 'A',
                    lexeme_creator => $self->signature,
                });
        }

        $dict->add_derivation({
            source_lexeme => $adj_lexemes[0],
            derived_lexeme => $adv_lexeme,
            deriv_type => 'A2D',
            derivation_creator => $self->signature,
        });
    }
}



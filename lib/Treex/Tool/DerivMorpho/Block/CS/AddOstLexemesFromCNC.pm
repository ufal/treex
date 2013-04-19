package Treex::Tool::DerivMorpho::Block::CS::AddOstLexemesFromCNC;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Tool::Lexicon::CS;
use CzechMorpho;

sub process_dictionary {
    my ($self,$dict) = @_;

    my $analyzer = CzechMorpho::Analyzer->new();

    open my $OST, '<:utf8', $self->my_directory.'/manual.AddOstLexemesFromCNC.txt' or log_fatal($!);
    while (<$OST>) {
        chomp;
        next if /\*/ or not $_;
        my $short_new_lemma = $_;

        my ($source_lexeme) = $dict->get_lexemes_by_lemma($short_new_lemma);
        if (not $source_lexeme) {
            my @long_lemmas = map { $_->{lemma} } grep {  $_->{tag} =~ /^NN.S1/ } $analyzer->analyze($short_new_lemma);
            if (@long_lemmas == 0) {
                print STDERR "warning: unknown noun $short_new_lemma\n";
            }
            elsif (@long_lemmas > 1) {
                print STDERR "warning: more possible lemmas for $short_new_lemma\n";
            }
            else {
                $dict->create_lexeme({
                    lemma  => $short_new_lemma,
                    mlemma => $long_lemmas[0],
                    pos => 'N',
                    lexeme_origin => 'ost-from-cnk',
                });
            }
        }
    }

    return $dict;
}

1;

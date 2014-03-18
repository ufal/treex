package Treex::Tool::DerivMorpho::Block::CS::RevertDerivationDirection;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';
use Treex::Core::Log;

##### zapracovani dat od Magdy z emailu z 12.3., puvodni nazev souboru: vymazat_s_hvezdickou_ostatni_do_databaze


sub process_dictionary {

    my ($self, $dict) = @_;

    open my $R, '<:utf8', $self->my_directory."manual.RevertDerivationDirection.txt" or log_fatal($!);
    log_info("Loading manually annotated instances");


  LINE:
    while (<$R>) {

        if (/(\w+) --> (\w+)/) { # analytik --> analytika
            my ($target_lemma,$source_lemma) = ($1,$2);

            my $source_lexeme = _create_if_nonexistent($source_lemma,'N',$dict);
            my $target_lexeme = _create_if_nonexistent($target_lemma,'N',$dict);

            if (not $source_lexeme or not $target_lexeme) {
                # TODO: resolve nonexisting lexemes
                next LINE;
            }

            if ( $target_lexeme eq ($source_lexeme->source_lexeme()||'')) {
                print "OPPOSITE LINK ALREADY PRESENT: $source_lemma -> $target_lemma\n";
                $source_lexeme->set_source_lexeme(undef);
            }

            print "Adding new relation: $source_lemma -> $target_lemma\n";
            $dict->add_derivation({
                source_lexeme => $source_lexeme,
                derived_lexeme => $target_lexeme,
                deriv_type => 'N2N',
                derivation_creator => $self->signature,
            });
        }
    }

    return $dict;
}


sub _create_if_nonexistent {
    my ($lemma,$pos,$dict) = @_;

    my @candidates = grep {$_->pos eq $pos} $dict->get_lexemes_by_lemma($lemma);
    if (not $candidates[0]) {
        log_info("No lexeme found for lemma=$lemma pos=$pos");
    }
    return $candidates[0]; # TODO: muze jich byt vic? a hlavne: kdyz se nenajde nic, mel by se vytvorit

}

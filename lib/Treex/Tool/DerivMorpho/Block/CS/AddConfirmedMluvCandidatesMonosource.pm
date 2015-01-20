package Treex::Tool::DerivMorpho::Block::CS::AddConfirmedMluvCandidatesMonosource;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';
use Treex::Core::Log;

##### zapracovani dat od Magdy z emailu z 12.3., puvodni nazev souboru: vymazat_s_hvezdickou_ostatni_do_databaze


has file => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q(file name to load),
);


sub process_dictionary {

    my ($self, $dict) = @_;

    open my $R, '<:utf8', ($self->file || $self->my_directory."manual.AddConfirmedMluvCandidatesMonosource.txt") or log_fatal($!);
    my %allowed_rules;
    log_info("Loading manually annotated instances");
    my ($source_pos,$source_suffix,$target_pos,$target_suffix);

  LINE:
    while (<$R>) {

        if ( /TRYING TO APPLY RULE (\w)-(\w+) --> (\w)-(\w+)/ ) { # TRYING TO APPLY RULE V-it --> N-ba
            ($source_pos,$source_suffix,$target_pos,$target_suffix) = ($1,$2,$3,$4);
        }

        elsif (/(\w+) --> (\w+)/) { # chodit --> chodba
            my ($source_lemma,$target_lemma) = ($1,$2);

            my $source_lexeme = _create_if_nonexistent($source_lemma,$source_pos,$dict);
            my $target_lexeme = _create_if_nonexistent($target_lemma,$target_pos,$dict);

            if (not $source_lexeme or not $target_lexeme) {
                # TODO: resolve nonexisting lexemes
                next LINE;
            }

            if (/\*/) {
                if ( $source_lexeme eq ($target_lexeme->source_lexeme()||'')) {
                    $target_lexeme->set_source_lexeme(undef);
                    print "Deleting relation $source_lemma -> $target_lemma\n";
                }
            }

            else {
                if ( $source_lexeme eq ($target_lexeme->source_lexeme()||'')) {
                    print "LINK ALREADY PRESENT: $source_lemma -> $target_lemma\n";
                }
                else {
                    print "Adding new relation: $source_lemma -> $target_lemma\n";
                    $dict->add_derivation({
                        source_lexeme => $source_lexeme,
                        derived_lexeme => $target_lexeme,
                        deriv_type => $source_pos.'2'.$target_pos,
                        derivation_creator => $self->signature.($self->file||""),
                    });
                }
            }
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

1;

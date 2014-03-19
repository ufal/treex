package Treex::Tool::DerivMorpho::Block::CS::AddOrDeleteLinksInClusters;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';
use Treex::Core::Log;


sub process_dictionary {

    my ($self, $dict) = @_;

    open my $R, '<:utf8', $self->my_directory."manual.RestructureClusters/s-hvezdickou-smazat_a_ostatni-do-databaze.txt" or log_fatal($!);

    while (<$R>) {

        my $to_delete = ($_ =~ s/^\s*\*\s*//);

        if (/^(\S+)\t(\S+)\t([A-Z])-.+?([A-Z]+)/) {
            my ($source_lemma, $target_lemma,$source_pos,$target_pos) = ($1,$2,$3,$4);

            my $source_lexeme = _create_if_nonexistent($source_lemma,$source_pos,$dict);
            my $target_lexeme = _create_if_nonexistent($target_lemma,$target_pos,$dict);

            if ($to_delete and /PRESENT/) {
                if ($source_lexeme and $target_lexeme and $source_lexeme eq ($target_lexeme->source_lexeme || '')) {
                    print "Deleting $source_lemma->$target_lemma\n";
                    $target_lexeme->set_source_lexeme(undef);
                }
            }

            if (not $to_delete and not /PRESENT/) {
                print "Trying to add $source_lemma -> $target_lemma\n";
                if ($source_lexeme and $target_lexeme) {
                    print "  Success\n";
                    $target_lexeme->set_source_lexeme($source_lexeme);
                }

            }
        }
    }

    # TODO: hvezdicka je tam nekdy kvuli tomu, ze se par lemmat chybne objevuje dvakrat - doresit !!!

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

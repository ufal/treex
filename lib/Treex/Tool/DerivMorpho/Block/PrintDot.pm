package Treex::Tool::DerivMorpho::Block::PrintDot;
use Moose;
#use Treex::Core::Common;
extends 'Treex::Tool::DerivMorpho::Block';
use utf8;

my $node_counter;

sub process_dictionary {
    my ($self,$dict) = @_;

#    my @lemmas = split /\s/, "prohlásit rozlehlý zahlcovat povaha obhajovat průměr věčný vyšroubovat ponížit políbit bobr pivovar nepřátelský hrnek vysmrkat předstírat básník hudba venkov církev vymést kontakt";#$ENV{LEMMAS}; ### TODO: troubles with encoding

    my @lemmas = split /\s/, "vymést kontakt vystřihnout dosáhnout";

    foreach my $lemma (@lemmas) {

        my ($lexeme) = $dict->get_lexemes_by_lemma($lemma);

        if ($lexeme) {

            while ($lexeme->source_lexeme) {
                $lexeme = $lexeme->source_lexeme;
            }

            print "\n";
            _print_subtree($lexeme, undef);
        }

        else {
            print STDERR "No lexem found for $lemma\n";
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


sub _print_subtree {
    my ($lexeme, $parent_dot_node_label) = @_;

    $node_counter++;
    my $node_label = "n$node_counter";

    print "\n";
    print "$node_label [label=\"" . $lexeme->lemma . "-" . $lexeme->pos ."\"];\n";

    if ($parent_dot_node_label) {
        print "$parent_dot_node_label->$node_label;\n";
    }
    foreach my $derived_lexeme ($lexeme->get_derived_lexemes) {
        _print_subtree($derived_lexeme,$node_label);
    }

}

1;

package Treex::Tool::DerivMorpho::Block::PrintStats;
use Moose;
#use Treex::Core::Common;
extends 'Treex::Tool::DerivMorpho::Block';

sub process_dictionary {
    my ($self,$dict) = @_;

    my %pos_cnt;
    my %pos2pos_cnt;
    my $relations_cnt = 0;
    my %derived_lexemes_cnt;

    foreach my $lexeme ($dict->get_lexemes) {
        $pos_cnt{$lexeme->pos}++;
        if ($lexeme->source_lexeme) {
            $relations_cnt++;
            $pos2pos_cnt{$lexeme->source_lexeme->pos."2".$lexeme->pos}++
        }

        $derived_lexemes_cnt{scalar($lexeme->get_derived_lexemes)}++;
    }

    print "LEXEMES\n";
    print "  Number of lexemes: ".scalar(@{$dict->_lexemes})."\n";
    print "  Number of lexemes by part of speech:\n";
    foreach my $pos (sort {$pos_cnt{$b}<=>$pos_cnt{$a}} keys %pos_cnt) {
        print "    $pos $pos_cnt{$pos}\n";
    }

    print "\nDERIVATIVE RELATIONS BETWEEN LEXEMES\n";
    print "  Total number of derivative relations: $relations_cnt\n";
    print "  Types of derivative relations (POS-to-POS):\n";
    foreach my $pos2pos (sort {$pos2pos_cnt{$b}<=>$pos2pos_cnt{$a}} keys %pos2pos_cnt) {
        print "    $pos2pos $pos2pos_cnt{$pos2pos}\n";
    }

    print "  Number of lexemes derived from a lexeme:\n";
    foreach my $derived (sort {$derived_lexemes_cnt{$b}<=>$derived_lexemes_cnt{$a}} keys %derived_lexemes_cnt) {
        print "    $derived $derived_lexemes_cnt{$derived}\n";
    }

    print "\nDERIVATIONAL CLUSTERS\n";

    my %signature_cnt;
    my %signature_example;
    my %touched;
    my $i;

    foreach my $lexeme ($dict->get_lexemes) {
        if (not $touched{$lexeme}) {
            my $root = $lexeme->get_root_lexeme;
            my $signature = $dict->_get_subtree_pos_signature($root,\%touched);
            $signature_cnt{$signature}++;
            $signature_example{$signature}{$root->lemma} = 1;
        }
    }

    print "Types of derivational clusters:\n";
    my @signatures = sort {$signature_cnt{$b}<=>$signature_cnt{$a}} keys %signature_cnt;
    foreach my $signature (@signatures) {
        print "    $signature_cnt{$signature} $signature: ";
        my @examples = keys %{$signature_example{$signature}};
        print join " ",grep {$_} @examples[0..20];
        print "\n";
    }

    return $dict;
}

1;

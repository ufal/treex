package Treex::Tool::DerivMorpho::Block::CS::ExtractOst;
use Moose;
use Treex::Tool::DerivMorpho::Block;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Core::Log;


sub process_dictionary {

    my ($self, $dict) = @_;


    foreach my $lexeme ($dict->get_lexemes) {

        print $lexeme->lemma." LEMMA \n";
        my @derived = $lexeme->get_derived_lexemes;
        print "Number of derived lexemes: ".scalar(@derived)."\n";

        my ($ost) = grep {$_->lemma =~ /ost$/} @derived;

#        print "Os

        my ($ita) = grep {$_->lemma =~ /ita$/} @derived;


        if ($ost and $ita) {

            print $ost->lemma, "\t", $ita->lemma, "\n";

        }


    }

    return $dict;

}


1;

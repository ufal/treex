package Treex::Tool::DerivMorpho::Block::PrintDeadjectivalDerivs;
use Moose;
#use Treex::Core::Common;
extends 'Treex::Tool::DerivMorpho::Block';
use utf8;

my $node_counter;

sub process_dictionary {
    my ($self,$dict) = @_;


    foreach my $adj_lexeme (grep {$_->pos eq "A"} $dict->get_lexemes) {
	foreach my $derived_lexeme ($adj_lexeme->get_derived_lexemes) {

	    print join "\t",($adj_lexeme->lemma, $derived_lexeme->lemma,$derived_lexeme->pos,$derived_lexeme->derivation_creator);
	    print "\n";

	}
    }
}

1;

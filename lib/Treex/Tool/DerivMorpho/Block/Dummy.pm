package Treex::Tool::DerivMorpho::Block::Dummy;
use Moose;
#use Treex::Core::Common;
extends 'Treex::Tool::DerivMorpho::Block';

sub process_dictionary {
    my ($self,$dict) = @_;
    $dict->create_lexeme({lemma=>'testlemma'});
    return $dict;
}

1;

package Treex::Tool::DerivMorpho::Block::Save;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

has filename => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => '_has_from_string',
    documentation => q(file name to store),
);

use Treex::Tool::DerivMorpho::Dictionary;

sub BUILD {
    print "Building Save\n";
}

sub process_dictionary {
    my ($self, $dict) = @_;
    print "Running Save\n";
    print "Saving ".scalar($dict->get_lexemes)." lexemes\n";
    $dict->save($self->filename);
    return $dict;
}

1;

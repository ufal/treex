package Treex::Tool::DerivMorpho::Block::Save;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

has file => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q(file name to store),
);

use Treex::Tool::DerivMorpho::Dictionary;

sub process_dictionary {
    my ($self, $dict) = @_;
    print "Saving ".scalar($dict->get_lexemes)." lexemes\n";
    $dict->save($self->file);
    return $dict;
}

1;

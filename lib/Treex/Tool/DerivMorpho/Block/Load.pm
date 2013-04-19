package Treex::Tool::DerivMorpho::Block::Load;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

has filename => (
    is            => 'ro',
    isa           => 'Str',
    predicate     => '_has_from_string',
    documentation => q(file name to load),
);

use Treex::Tool::DerivMorpho::Dictionary;

sub process_dictionary {
    my ($self, $dict) = @_;
    $dict = Treex::Tool::DerivMorpho::Dictionary->new;
    $dict->load($self->filename);
    return $dict;
}

1;

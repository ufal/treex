package Treex::Tool::DerivMorpho::Block::Load;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

has file => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q(file name to load),
);

use Treex::Tool::DerivMorpho::Dictionary;

sub process_dictionary {
    my ($self, $dict) = @_;
    $dict = Treex::Tool::DerivMorpho::Dictionary->new;
    $dict->load($self->file);
    return $dict;
}

1;

package Treex::Tool::DerivMorpho::Block::Load;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

has file => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q(file name to load),
);

has limit => (
    is            => 'ro',
    isa           => 'Int',
    documentation => 'maximum number of lexemes to load (risky because of forward links)',
);


use Treex::Tool::DerivMorpho::Dictionary;

sub process_dictionary {
    my ($self, $dict) = @_;
    $dict = Treex::Tool::DerivMorpho::Dictionary->new;
    $dict->load($self->file,{limit=>$self->limit});
    return $dict;
}

1;

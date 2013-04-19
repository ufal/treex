package Treex::Tool::DerivMorpho::Block::CreateEmpty;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Tool::DerivMorpho::Dictionary;

sub process_dictionary {
    return Treex::Tool::DerivMorpho::Dictionary->new;
}

1;

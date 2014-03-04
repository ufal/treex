package Treex::Block::SemevalABSA::FirstNounAboveSubjAdj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_ttree {
    my ( $self, $ttree ) = @_;

}

1;

# Pokud jsem podmet konstrukce, jejiz patiens je rozvity hodnoticim adjektivem, jsem aspekt.
#
#     Pr. The bagel ACT have an ourstanding RSTR taste PAT.

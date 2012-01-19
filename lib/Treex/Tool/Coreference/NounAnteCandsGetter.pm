package Treex::Tool::Coreference::NounAnteCandsGetter;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::SemNounFilter;

with 'Treex::Tool::Coreference::AnteCandsGetter';

sub _build_cand_filter {
    my ($self) = @_;

    return Treex::Tool::Coreference::SemNounFilter->new(); 
}

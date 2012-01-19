package Treex::Tool::Coreference::SemNounFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::NodeFilter';

# semantic noun filtering
sub is_candidate {
    my ($self, $node) = @_;
    return ( defined $node->gram_sempos && ($node->gram_sempos =~ /^n/) 
            && (!$node->gram_person || ($node->gram_person !~ /1|2/)) );
}

# TODO doc

1;

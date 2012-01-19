package Treex::Tool::Coreference::CS::RelPronAnaphFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::NodeFilter';

# according to rule presented in Nguy et al. (2009)
# nodes with the t_lemma #PersPron and third person in gram/person
sub is_candidate {
    my ($self, $t_node) = @_;

    return ( $t_node->get_lex_anode && $t_node->get_lex_anode->tag =~ /^.[149EJK\?]/ );
}

# TODO doc

1;

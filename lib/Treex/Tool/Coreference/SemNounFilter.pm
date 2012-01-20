package Treex::Tool::Coreference::SemNounFilter;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::NodeFilter';

# semantic noun filtering
sub is_candidate {
    my ($self, $node) = @_;
    my $anode = $node->get_lex_anode;
    
    my $is_sem_noun = defined $node->gram_sempos && ($node->gram_sempos =~ /^n/);
    my $not_first_second_pers = !$node->gram_person || ($node->gram_person !~ /1|2/);
    # if the node is not generated, leave just nouns, pronouns, adjectives and foreign words
    my $not_certain_pos = !$anode || ($anode->tag !~ /^[CJRTDIZV]/);

    return ($is_sem_noun && $not_first_second_pers );
}

# TODO doc

1;

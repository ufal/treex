package Treex::Block::T2T::CS2EN::FixDoubleNegative;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # only solve verbs
    return if ( $t_node->formeme !~ /^v/ );

    my (@negs) = grep { $_->t_lemma =~ /^(no(_one|body|where|thing|ne|)?|never|not)$/ } $t_node->get_clause_edescendants();

    
    if ( @negs == 1 and $negs[0]->t_lemma eq 'no' and $negs[0]->get_parent->formeme ne 'n:subj' ) {
        my $neg = shift @negs;
        
        if ( not $neg->src_tnode or $neg->src_tnode->t_lemma ne 'ne' ){
            $neg->set_t_lemma('any');
            $neg->set_t_lemma_origin('rule-FixDoubleNegative');
        }        
    }
    
    if (@negs) {
        $t_node->set_gram_negation('neg0');
    }
}

1;

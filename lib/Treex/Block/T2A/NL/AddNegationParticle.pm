package Treex::Block::T2A::NL::AddNegationParticle;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddNegationParticle';

override 'particle_for' => sub {
    my ( $self, $t_node ) = @_;

    # avoid cases where the negation is included in the lemma 
    return if ($t_node->formeme =~ /^ad[jv]/ and $t_node->t_lemma =~ /^(on|in)/ );    
    # default negation: niet
    return 'niet';
};

override 'postprocess' => sub {
    my ( $self, $t_node, $a_node, $neg_node ) = @_;

    # negation is an adverb
    $neg_node->set_iset( 'pos' => 'adv' );

    # we are OK with the position before the node for adverbs, adjectives
    return if ( !$a_node->is_verb );

    # shift the negation after all subjects and direct objects
    $neg_node->shift_after_node($a_node);
    while ( my $a_right = $neg_node->get_right_neighbor() ) {
        my ($t_right) = $a_right->get_referencing_nodes('a/lex.rf');
        last if ( !$t_right or $t_right->formeme !~ /n:(subj|obj)/ );
        $neg_node->shift_after_node($a_right);
    }
    return;
};

1;

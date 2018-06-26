package Treex::Block::Print::AddOna;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS::PersonalRoles;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_ttree {
    my ($self, $ttree) = @_;
    my @tnodes = $ttree->get_descendants( { ordered => 1 } );
    for my $tnode (@tnodes){
        my $tverb = $tnode->get_parent();
        if (    $tnode->formeme eq 'drop'
            and ($tnode->gram_gender || '') eq 'fem'
            and ($tnode->gram_number || '') eq 'sg'
            and $tnode->functor eq 'ACT'
            and ($tverb->gram_tense || '') =~ /sim|post/
            and ($tverb->gram_verbmod || '') eq 'ind'
            ){
            # Make sure the verb is not plural
            my $averb = $tverb->get_lex_anode or next;
            next if $averb->tag =~ /^...P/;
            # nor copula with non-feminine adjective.
            if ($tverb->t_lemma eq 'být'){
                my $tpnom = $tverb->get_children({following_only=>1, first_only=>1}) or next;
                my $apnom = $tpnom->get_lex_anode or next;
                next if $apnom->tag =~ /^A.[^F]/;
            }

            # Add "ona" only if the antecedent is in a different sentence.
            my $iter = $tnode;
            my $antec;
            while ($iter->formeme eq 'drop'){
              ($antec) = $iter->get_coref_text_nodes();
              last if !$antec;
              $iter = $antec;
            }
            next if !$antec or $antec->root == $tnode->root;

            # Filter out non-human feminine nouns (e.g. "vláda", "zpráva").
            next if !$self->is_female_person($antec);

            my ($first_averb) = grep {$_->tag =~ /^V/} $tverb->get_anodes({ordered=>1});
            my $ona = $first_averb->create_child(form=>'ona');
            $ona->shift_before_node($first_averb);
            if ($ona->ord == 1){
              $ona->set_form('Ona');
              my $second_word = $ona->get_next_node;
              $second_word->set_form(lcfirst $second_word->form)
            }
        }
    }
    my $atree = $ttree->get_zone()->get_atree();
    my $sentence = "";
    foreach my $a_node ( $atree->get_descendants( { ordered => 1 } ) ) {
        $sentence .= $a_node->form;
        $sentence .= " " if !$a_node->no_space_after;
    }
    $sentence =~ s/ $//;
    print {$self->_file_handle} $sentence . "\n";
    return;
}

sub is_female_person{
    my ($self, $tnode) = @_;
    # Unfortunatelly, $node->is_name_of_person is not filled in the Czech t-analysis.
    # We already know that the coref chain was tagged with gram_gender=fem,
    # but we aim at high precision (at the cost of low recall), so we double check the gender.
    return 0 if ($tnode->gram_gender || '') ne 'fem';
    my $anode = $tnode->get_lex_anode or return 0;
    return 0 if $anode->tag =~ /^N.[^FX]/;
    return 1 if Treex::Tool::Lexicon::CS::PersonalRoles::is_personal_role($tnode->t_lemma);
    return 1 if $tnode->t_lemma =~ /^\p{Uppercase}.*(ová|í)$/; # Most Czech female surnames end with "ová"
    my $n_node = $tnode->get_n_node() or return 0;
    return 1 if $n_node->ne_type eq 'pf'; # pf = first name (ps=surname, but those are solved above)
    return 0;
}

1;

# Preprocessing for cs->en NMT.
# Author: Martin Popel
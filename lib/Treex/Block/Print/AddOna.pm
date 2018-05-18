package Treex::Block::Print::AddOna;
use Moose;
use Treex::Core::Common;
#use Treex::Tool::Lexicon::CS;
use Treex::Tool::Lexicon::CS::PersonalRoles;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_ttree {
    my ($self, $ttree) = @_;
    my @tnodes = $ttree->get_descendants( { ordered => 1 } );
    for my $tnode (@tnodes){
        if (    $tnode->formeme eq 'drop'
            and $tnode->gram_gender eq 'fem'
            and $tnode->gram_number eq 'sg'
            and $tnode->functor eq 'ACT'
            and ($tnode->get_parent->gram_tense || '') =~ /sim|post/
            and $tnode->get_parent->gram_verbmod eq 'ind'
            # Without restricting to dicendi verbs there were many cases
            # where the antecedent was actually feminine-gender non-human
            # "e.g. vláda"), thus "it" rather than "she" should be used in the translation.
            #and Treex::Tool::Lexicon::CS::is_dicendi_verb($tnode->get_parent->t_lemma)
            and $self->is_person($tnode->get_parent)
            ){

            # Don't add "ona" if the antecedent is not in a different sentence.
            my $iter = $tnode;
            my $antec;
            while ($iter->formeme eq 'drop'){
              ($antec) = $iter->get_coref_text_nodes();
              last if !$antec;
              $iter = $antec;
            }
            next if !$antec or $antec->root == $tnode->root;

            my $verb = $tnode->get_parent->get_lex_anode or next;
            my $ona = $verb->create_child(form=>'ona');
            $ona->shift_before_node($verb);
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

sub is_person{
    my ($self, $tnode) = @_;
    # Unfortunatelly, $node->is_name_of_person is not filled in the Czech t-analysis.
    return 1 if Treex::Tool::Lexicon::CS::PersonalRoles::is_personal_role($tnode->t_lemma);
    my $anode = $tnode->get_lex_anode() or return 0;
    return 1 if $anode->lemma =~ /;Y$/;
    #my $n_node = $tnode->get_n_node() or return 0;
    my $n_node = $anode->n_node or return 0;
    return 1 if $n_node->ne_type =~ /^p/;
    return 0;
}

1;

# Preprocessing for cs->en NMT.
# Author: Martin Popel
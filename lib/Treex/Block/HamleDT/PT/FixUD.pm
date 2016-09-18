package Treex::Block::HamleDT::PT::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_sent_id($root);
    $self->fix_morphology($root);
    $self->fix_auxiliary_verbs($root);
    $self->regenerate_upos($root);
    $self->fix_root_punct($root);
    $self->fix_case_mark($root);
}



#------------------------------------------------------------------------------
# Updates sentence id from "pt-s106" to just "s106" because Write::CoNLLU now
# automatically adds the zone language and the resulting comment will read
# sent_id s106/pt
#------------------------------------------------------------------------------
sub fix_sent_id
{
    my $self = shift;
    my $root = shift;
    my $zone = $root->get_zone();
    my $bundle = $root->get_bundle();
    # Both bundle id and tree id should be processed because we cannot be sure which one will be used by downstream blocks / applications.
    my $language = $zone->language();
    my $bid = $bundle->id();
    my $tid = $root->id();
    $bid =~ s/^$language-//;
    $tid =~ s/^$language-//;
    $bundle->set_id($bid) if($bid ne '');
    $root->set_id($tid) if($tid ne '');
}



#------------------------------------------------------------------------------
# Fixes known issues in features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $iset = $node->iset();
        # The common gender should not be used in Spanish.
        # It should be empty, which means any gender, which in case of Spanish is masculine or feminine.
        if($iset->is_common_gender())
        {
            $iset->set('gender', '');
        }
        # The gender, number, person and verbform features cannot occur with adpositions, conjunctions, particles, interjections and punctuation.
        if($iset->pos() =~ m/^(adv|adp|conj|part|int|punc)$/)
        {
            $iset->clear('gender', 'number', 'person', 'verbform');
        }
        # The verbform feature also cannot occur with pronouns, determiners and numerals.
        if($iset->is_pronoun() || $iset->is_numeral())
        {
            $iset->clear('verbform');
        }
        # The case feature can only occur with personal pronouns.
        if(!$iset->is_pronoun() || $form =~ m/^(uno|Éstas|l\')$/i) #'
        {
            $iset->clear('case');
        }
        # The mood and tense features can only occur with verbs.
        if(!$iset->is_verb())
        {
            $iset->clear('mood', 'tense');
        }
        # Fix verbal features.
        if($iset->is_verb())
        {
            # Every verb has a verbform. Those that do not have any verbform yet, are probably finite.
            if($iset->verbform() eq '')
            {
                $iset->set('verbform', 'fin');
            }
        }
        # The word "muito" ("much"), originally tagged "adv <quant>" in Bosque, was wrongly converted as determiner.
        # We should change it back to adverb, with the NumType=Card feature marking that it is an adverb of degree or quantity.
        # However, there are also occurrences that were originally tagged "pron-det <quant>|M|S", these modify a noun ("muito tempo" = "much time")
        # and should stay tagged as determiners!
        if($form =~ m/^muito$/i && $node->is_determiner() && $node->conll_pos() =~ m/adv/)
        {
            $iset->set_hash({'pos' => 'adv', 'prontype' => 'ind', 'numtype' => 'card'});
        }
        # Mark words in foreign scripts.
        my $letters_only = $form;
        $letters_only =~ s/\PL//g;
        # Exclude also Latin letters.
        $letters_only =~ s/\p{Latin}//g;
        if($letters_only ne '')
        {
            $iset->set('foreign', 'fscript');
        }
        # The word "I" is wrongly tagged CONJ, although it is a Roman numeral or the English pronoun in names.
        if($self->get_node_spanstring($node) =~ m/^(I &amp; D|I Do Not Want What I Haven't Got|I Wanna Live|I Want to Cross Over|Am I Not Your Girl\?)$/) #'
        {
            my @subtree = $self->get_node_subtree($node);
            for(my $i = 0; $i <= $#subtree; $i++)
            {
                $iset->set_hash({}); # UPOS = X
                if($i > 0)
                {
                    $subtree[$i]->set_parent($subtree[0]);
                    $subtree[$i]->set_deprel('name');
                }
            }
        }
        elsif($form =~ m/^(I|II|III|IV|V|VI|VII|VIII|IX)$/)
        # a I Divisão
        # de a I Guerra Mundial
        # de o I Congresso Nacional de Surdos... (subordinate clause)
        # a Ponte de D.Luís I
        # D.Maria I
        # João Paulo I
        # I -- ... (sentence number in a list)
        {
            $iset->set_hash({'pos' => 'adj', 'numtype' => 'ord', 'numform' => 'roman'});
        }
        # The word "si" is wrongly tagged SCONJ in multi-word expressions where it is PRON (SCONJ leaked from Spanish).
        # Examples: em si, entre si, por si
        if($form eq 'si' && $iset->is_subordinator() && $node->deprel() eq 'mwe')
        {
            $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => 'reflex', 'person' => 3, 'case' => 'acc', 'prepcase' => 'pre'});
            $node->set_conll_pos('PRON') if($node->conll_pos() eq 'SCONJ');
            # Change lemma from "si" to "se".
            $node->set_lemma('se');
        }
        # The word "Nacional" in multi-word named entities is wrongly tagged PROPN, should be ADJ.
        if($form eq 'Nacional' && $iset->is_proper_noun())
        {
            $iset->set('pos', 'adj');
            $iset->clear('nountype');
            $node->set_deprel('amod') if($node->deprel() eq 'name');
        }
        # The token "$/" should really read "/" and it should be tagged SYM. It usually has the "per" meaning. Example:
        # pagar US$ 1,5 bilhão $/ ano
        if($form eq '$/')
        {
            $node->set_form('/');
            $node->set_lemma('/');
            $iset->set_hash({'pos' => 'sym'});
        }
    }
}



#------------------------------------------------------------------------------
# There are dozens of verbs tagged AUX. Many of them occur only once and their
# auxiliary status is highly suspicious.
#------------------------------------------------------------------------------
sub fix_auxiliary_verbs
{
    my $self = shift;
    my $root = shift;
    # The following verbs may occur as auxiliaries, at least in certain contexts (vir, passar, parecer, acabar, chegar and continuar are disputable).
    my $re_aux = 'ter|haver|estar|ser|ir|poder|dever|vir|passar|parecer|acabar|chegar|continuar';
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if($node->iset()->is_auxiliary() && $node->lemma() !~ m/^($re_aux)$/)
        {
            $node->iset()->set('verbtype', '');
            # Often the parent is a verb which really should be treated as auxiliary.
            # We have to check that our own deprel is aux or auxpass; in particular, it should not be conj.
            my $parent = $node->parent();
            if($node->deprel() =~ m/^aux(pass)?$/ && $parent->is_verb() && $parent->lemma() =~ m/^($re_aux)$/)
            {
                $node->set_parent($parent->parent());
                $node->set_deprel($parent->deprel());
                $parent->set_parent($node);
                $parent->set_deprel('aux');
                $parent->iset()->set('verbtype', 'aux');
                my @pchildren = $parent->children();
                foreach my $c (@pchildren)
                {
                    $c->set_parent($node);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# After changes done to Interset (including part of speech) generates the
# universal part-of-speech tag anew.
#------------------------------------------------------------------------------
sub regenerate_upos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        $node->set_tag($node->iset()->get_upos());
    }
}



#------------------------------------------------------------------------------
# Fixes sentence-final punctuation attached to the artificial root node.
#------------------------------------------------------------------------------
sub fix_root_punct
{
    my $self = shift;
    my $root = shift;
    my @children = $root->children();
    if(scalar(@children)==2 && $children[1]->is_punctuation())
    {
        $children[1]->set_parent($children[0]);
        $children[1]->set_deprel('punct');
    }
}



#------------------------------------------------------------------------------
# Changes the relation between a preposition and a verb (infinitive) from case
# to mark. Miguel has done something in that direction but there are still many
# occurrences where this has not been fixed.
#------------------------------------------------------------------------------
sub fix_case_mark
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'case')
        {
            my $parent = $node->parent();
            # Most prepositions modify infinitives: para preparar, en ir, de retornar...
            if($parent->is_infinitive())
            {
                $node->set_deprel('mark');
            }
        }
    }
    # There is a bug caused by splitting preposition + determiner contractions:
    # "desta vez" ("this time") is a MWE attached directly to the ROOT node.
    if($nodes[0]->parent()->is_root() && $nodes[0]->form() eq 'De' &&
       $nodes[1]->parent()->is_root() && $nodes[1]->form() eq 'esta')
    {
        $nodes[0]->set_deprel('root');
        $nodes[1]->set_parent($nodes[0]);
        $nodes[1]->set_deprel('mwe');
    }
}



#------------------------------------------------------------------------------
# Collects all nodes in a subtree of a given node. Useful for fixing known
# annotation errors, see also get_node_spanstring(). Returns ordered list.
#------------------------------------------------------------------------------
sub get_node_subtree
{
    my $self = shift;
    my $node = shift;
    my @nodes = $node->get_descendants({'add_self' => 1, 'ordered' => 1});
    return @nodes;
}



#------------------------------------------------------------------------------
# Collects word forms of all nodes in a subtree of a given node. Useful to
# uniquely identify sentences or their parts that are known to contain
# annotation errors. (We do not want to use node IDs because they are not fixed
# enough in all treebanks.) Example usage:
# if($self->get_node_spanstring($node) =~ m/^peça a URV em a sua mesada$/)
#------------------------------------------------------------------------------
sub get_node_spanstring
{
    my $self = shift;
    my $node = shift;
    my @nodes = $self->get_node_subtree($node);
    return join(' ', map {$_->form() // ''} (@nodes));
}



1;

=over

=item Treex::Block::HamleDT::PT::FixUD

This is a temporary block that should fix selected known problems in the Portuguese UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

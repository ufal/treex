package Treex::Block::HamleDT::DE::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_root_punct($root);
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
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        # Conll/pos contains the automatically predicted STTS POS tag.
        my $stts = $node->conll_pos();
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
        # The mood and tense features can only occur with verbs.
        if(!$iset->is_verb())
        {
            $iset->clear('mood', 'tense');
        }
        # Fix articles. Warning: the indefinite article, "ein", may also be a numeral. The definite article, "der", may also be a relative pronoun.
        if($node->is_determiner())
        {
            if($lemma eq 'd' && $stts eq 'ART')
            {
                $lemma = 'der';
                $node->set_lemma($lemma);
                $iset->set('prontype', 'art');
                $iset->set('definiteness', 'def');
            }
            elsif($lemma eq 'ein' && $stts eq 'ART')
            {
                $iset->set('prontype', 'art');
                $iset->set('definiteness', 'ind');
            }
        }
        # Fix personal pronouns.
        if($node->is_pronoun() && $stts eq 'PPER')
        {
            if($lemma eq 'ich')
            {
                # Should we set case as well? Nom "ich", Dat "mir", Acc "mich".
                $iset->set_hash({'prontype' => 'prs', 'person' => 1, 'number' => 'sing'});
            }
            elsif($lemma eq 'wir')
            {
                # Nom "wir", Dat "uns", Acc "uns".
                $iset->set_hash({'prontype' => 'prs', 'person' => 1, 'number' => 'plur'});
            }
            elsif($lemma eq 'du')
            {
                # Nom "du", Dat "dir", Acc "dich".
                $iset->set_hash({'prontype' => 'prs', 'person' => 2, 'number' => 'sing', 'politeness' => 'inf'});
            }
            elsif($lemma eq 'ihr')
            {
                # Nom "ihr", Dat "euch", Acc "euch".
                $iset->set_hash({'prontype' => 'prs', 'person' => 2, 'number' => 'plur', 'politeness' => 'inf'});
            }
            elsif($lemma eq 'er')
            {
                # Nom "er", Dat "ihm", Acc "ihn".
                $iset->set_hash({'prontype' => 'prs', 'person' => 3, 'number' => 'sing', 'gender' => 'masc'});
            }
            elsif($lemma eq 'es')
            {
                # Nom "es", Dat "ihm", Acc "ihn".
                $iset->set_hash({'prontype' => 'prs', 'person' => 3, 'number' => 'sing', 'gender' => 'neut'});
            }
            elsif($lemma eq 'sie')
            {
                # Either singular feminine ("she"), or plural any gender ("they"). The lemma does not change.
                # Fem Sing: Nom "sie", Dat "ihr", Acc "ihr".
                # Plur:     Nom "sie", Dat "ihnen", Acc "ihnen".
                $iset->set_hash({'prontype' => 'prs', 'person' => 3});
            }
            elsif($lemma eq 'Sie|sie')
            {
                # Usually polite 2nd person any number (semantically; formally it is 3rd person).
                # But it could also be the above (normal 3rd person), capitalized because of sentence start.
                $iset->set_hash({'prontype' => 'prs', 'person' => 2, 'politeness' => 'pol'});
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

=item Treex::Block::HamleDT::DE::FixUD

This is a temporary block that should fix selected known problems in the German UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

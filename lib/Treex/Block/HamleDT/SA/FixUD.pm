package Treex::Block::HamleDT::SA::FixUD;
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
    $self->fix_case_mark($root);
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
        # Fix verbal features.
        if($iset->is_verb())
        {
            # Every verb has a verbform. Those that do not have any verbform yet, are probably finite.
            if($iset->verbform() eq '')
            {
                $iset->set('verbform', 'fin');
            }
        }
        # Remove the XPOSTAG value. It is always 'X' and it is not useful.
        # Note that setting undef would result in it later being rewritten by a copy of UPOSTAG.
        $node->set_conll_pos('_');
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

=item Treex::Block::HamleDT::SA::FixUD

This is a temporary block that should fix selected known problems in the Sanskrit UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

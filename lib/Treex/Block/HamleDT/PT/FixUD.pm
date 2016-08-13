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
        # The person feature also cannot occur with non-pronominal nouns, adjectives and numerals.
        if((($iset->is_noun() || $iset->is_adjective()) && !$iset->is_pronoun()) || $iset->is_numeral())
        {
            $iset->clear('person');
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
        # Mark words in foreign scripts.
        my $letters_only = $form;
        $letters_only =~ s/\PL//g;
        # Exclude also Latin letters.
        $letters_only =~ s/\p{Latin}//g;
        if($letters_only ne '')
        {
            $iset->set('foreign', 'fscript');
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
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'case')
        {
            my $parent = $node->parent();
            # Most prepositions modify infinitives: para preparar, en ir, de retornar...
            # Some exceptions: desde hace cinco años
            if($parent->is_infinitive() || $parent->form() =~ m/^hace$/i)
            {
                $node->set_deprel('mark');
            }
        }
    }
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

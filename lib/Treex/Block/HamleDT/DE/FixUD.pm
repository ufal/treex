package Treex::Block::HamleDT::DE::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToUD;
extends 'Treex::Block::HamleDT::SplitFusedWords';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # Fix relations before morphology. The fixes depend only on UPOS tags, not on morphology (e.g. NOUN should not be attached as det).
    # And with better relations we will be more able to disambiguate morphological case and gender.
    $self->convert_deprels($root);
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    # Coordinating conjunctions and punctuation should now be attached to the following conjunct.
    # The Coordination phrase class already outputs the new structure, hence simple
    # conversion to phrases and back should do the trick.
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToUD
    (
        'prep_is_head'           => 0,
        'coordination_head_rule' => 'first_conjunct'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
}



my %v12deprel =
(
    'dobj'      => 'obj',
    'nsubjpass' => 'nsubj:pass',
    'csubjpass' => 'csubj:pass',
    'auxpass'   => 'aux:pass',
    'neg'       => 'advmod',
    'name'      => 'flat',
    'foreign'   => 'flat:foreign',
    'mwe'       => 'fixed'
);



#------------------------------------------------------------------------------
# Converts dependency relations from UD v1 to v2.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my $deprel = $node->deprel();
        if(exists($v12deprel{$deprel}))
        {
            $node->set_deprel($v12deprel{$deprel});
        }
        elsif($deprel eq 'nmod' && $parent->is_verb())
        {
            $node->set_deprel('obl');
        }
        # Fix inherently reflexive verbs.
        if($node->is_reflexive() && $self->is_inherently_reflexive_verb($parent->lemma()))
        {
            $node->set_deprel('expl:pv');
        }
    }
}



#------------------------------------------------------------------------------
# Identifies German inherently reflexive verbs (echte reflexive Verben). Note
# that there are very few verbs where we can automatically say that the they
# are reflexive. In some cases they are mostly reflexive, but the transitive
# usage cannot be excluded, although it is rare, obsolete or limited to some
# dialects. In other cases the reflexive use has a meaning significantly
# different from the transitive use, and it would deserve to be annotated using
# expl:pv, but we cannot tell the two usages apart automatically.
#------------------------------------------------------------------------------
sub is_inherently_reflexive_verb
{
    my $self = shift;
    my $lemma = shift;
    # The following examples are taken from Knaurs Grammatik der deutschen Sprache, 1989
    # (first line) + some additions (second line).
    # with accusative
    my @irva = qw(
        bedanken beeilen befinden begeben erholen nähern schämen sorgen verlieben
        anfreunden weigern
    );
    # with dative
    my @irvd = qw(
        aneignen anmaßen ausbitten einbilden getrauen gleichbleiben vornehmen
    );
    my $re = join('|', (@irva, @irvd));
    return $lemma =~ m/^($re)$/;
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
        $self->fix_mwt_capitalization($node);
        my $form = $node->form();
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        if($lemma eq 'nicht')
        {
            $iset->set('polarity', 'neg');
        }
    }
    # It is possible that we changed the form of a multi-word token.
    # Therefore we must re-generate the sentence text.
    $root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Identifies and returns the subject of a verb or another predicate. If the
# verb is copula or auxiliary, finds the subject of its parent.
#------------------------------------------------------------------------------
sub get_subject
{
    my $self = shift;
    my $node = shift;
    my @subj = grep {$_->deprel() =~ m/subj/} $node->children();
    # There should not be more than one subject (coordination is annotated differently).
    # The caller expects at most one node, so we will not return more than that, even if present.
    return $subj[0] if(scalar(@subj)>0);
    return undef if($node->is_root());
    return $self->get_subject($node->parent()) if($node->deprel() =~ m/^(aux|cop)/);
    return undef;
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
# Makes capitalization of muti-word tokens consistent with capitalization of
# their parts.
#------------------------------------------------------------------------------
sub fix_mwt_capitalization
{
    my $self = shift;
    my $node = shift;
    # Is this node part of a multi-word token?
    if($node->is_fused())
    {
        my $pform = $node->form();
        my $fform = $node->get_fusion();
        # It is not always clear whether we want to fix the mwt or the part.
        # In German however, the most frequent error seems to be that in the
        # beginning of a sentence, the mwt is not capitalized while its first
        # part is.
        if($node->get_fusion_start() == $node && $node->ord() == 1 && is_capitalized($pform) && is_lowercase($fform))
        {
            $fform =~ s/^(.)/\u$1/;
            $node->set_fused_form($fform);
        }
    }
}



#------------------------------------------------------------------------------
# Checks whether a string is all-uppercase.
#------------------------------------------------------------------------------
sub is_uppercase
{
    my $string = shift;
    return $string eq uc($string);
}



#------------------------------------------------------------------------------
# Checks whether a string is all-lowercase.
#------------------------------------------------------------------------------
sub is_lowercase
{
    my $string = shift;
    return $string eq lc($string);
}



#------------------------------------------------------------------------------
# Checks whether a string is capitalized.
#------------------------------------------------------------------------------
sub is_capitalized
{
    my $string = shift;
    return 0 if(length($string)==0);
    $string =~ m/^(.)(.*)$/;
    my $head = $1;
    my $tail = $2;
    return is_uppercase($head) && !is_uppercase($tail);
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

Copyright © 2016, 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

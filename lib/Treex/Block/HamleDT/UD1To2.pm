package Treex::Block::HamleDT::UD1To2;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToUD;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_verbal_copulas($root);
    $self->regenerate_upos($root);
    # Fix relations before morphology. The fixes depend only on UPOS tags, not on morphology (e.g. NOUN should not be attached as det).
    # And with better relations we will be more able to disambiguate morphological case and gender.
    $self->convert_deprels($root);
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
    $self->convert_chained_relations_to_orphans($root);
}



#------------------------------------------------------------------------------
# Verbal copulas must now have the tag AUX, not VERB.
#------------------------------------------------------------------------------
sub fix_verbal_copulas
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # Verbal copulas should be AUX and not VERB.
        if($node->is_verb() && $node->deprel() eq 'cop')
        {
            $node->iset()->set('verbtype', 'aux');
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



my %v12deprel =
(
    'dobj'       => 'obj',
    'dobj:cau'   => 'obj:cau',
    'dobj:lvc'   => 'obj:lvc',
    'nsubjpass'  => 'nsubj:pass',
    'csubjpass'  => 'csubj:pass',
    'auxpass'    => 'aux:pass',
    'auxpass:reflex' => 'expl:pass',
    'nmod:agent' => 'obl:agent',
    # Conversion of the neg relation is nontrivial, see below.
    #'neg'        => 'advmod',
    'name'       => 'flat',
    ###!!! We may want to convert 'foreign' to just 'flat' and check that both the child and the parent have the feature Foreign=Yes.
    'foreign'    => 'flat:foreign',
    'mwe'        => 'fixed',
    # nummod:entity was used in Russian and they discarded it for v2.
    'nummod:entity' => 'nummod'
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
        my $iset = $node->iset();
        # Just in case the data is buggy...
        if($parent->is_root())
        {
            $deprel = 'root';
            $node->set_deprel('root');
        }
        # If we are removing the 'neg' relation, make sure that the node has one of the features Polarity=Neg or PronType=Neg.
        if($deprel eq 'neg')
        {
            if($node->is_pronominal())
            {
                $iset->set('prontype', 'neg');
            }
            else
            {
                $iset->set('polarity', 'neg');
            }
            # By default we assume that the neg relation is used for negative particles such as English "not".
            # These particles should now be attached using the advmod relation.
            # However, in Uyghur the neg relation was used for the negative copula "emes" and the new relation should be cop.
            if($node->form() eq 'ئەمەس')
            {
                $node->set_deprel('cop');
            }
            else
            {
                $node->set_deprel('advmod');
            }
        }
        if(exists($v12deprel{$deprel}))
        {
            $node->set_deprel($v12deprel{$deprel});
        }
        # Split 'nmod' to 'nmod' and 'obl'. This is an approximation only.
        # If an 'nmod' depends on a nominal predicate, we do not know whether it is
        # a location/time adjunct (as in "he will be smarter <next time>"), or just
        # a modifier of a nominal (as in "he will be professor <of linguistics>").
        elsif($deprel eq 'nmod' && $parent->is_verb())
        {
            $node->set_deprel('obl');
        }
    }
}



#------------------------------------------------------------------------------
# At one point in time, there was a proposal to encode orphaned arguments using
# chained relations like "conj>dobj" and "conj>nmod". This proposal was not
# selected for v2 guidelines but some data has been annotated this way, hoping
# that it would comply with v2. Simple cases can be converted automatically to
# the approach used in v2.
#------------------------------------------------------------------------------
sub convert_chained_relations_to_orphans
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my @chained = grep {$_->deprel() =~ m/^conj>/} ($node->children());
        my $n = scalar(@chained);
        if($n > 0)
        {
            if($n != 2)
            {
                log_warn("Cannot convert chained conj>something relations when the number of orphans is $n");
                next;
            }
            else
            {
                # Use the obliqueness hierarchy to determine which orphan will be promoted.
                my $promote;
                my $orphan;
                if($chained[0]->deprel() =~ m/nsubj/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/nsubj/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/dobj/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/dobj/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/iobj/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/iobj/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/nmod/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/nmod/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/advmod/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/advmod/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/csubj/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/csubj/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/xcomp/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/xcomp/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/ccomp/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/ccomp/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                elsif($chained[0]->deprel() =~ m/advcl/)
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                elsif($chained[1]->deprel() =~ m/advcl/)
                {
                    $promote = $chained[1];
                    $orphan = $chained[0];
                }
                else
                {
                    $promote = $chained[0];
                    $orphan = $chained[1];
                }
                push(@{$promote->wild()->{deps}}, $promote->parent()->ord().':'.$promote->deprel());
                push(@{$orphan->wild()->{deps}}, $orphan->parent()->ord().':'.$orphan->deprel());
                $promote->set_deprel('conj');
                $orphan->set_parent($promote);
                $orphan->set_deprel('orphan');
            }
        }
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

=item Treex::Block::HamleDT::UD1To2

This is a temporary block that should do the language-independent part of conversion
from Universal Dependencies v1 to v2.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

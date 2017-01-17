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
    # Fix relations before morphology. The fixes depend only on UPOS tags, not on morphology (e.g. NOUN should not be attached as det).
    # And with better relations we will be more able to disambiguate morphological case and gender.
    $self->convert_deprels($root);
    $self->regenerate_upos($root);
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
    }
}



#------------------------------------------------------------------------------
# Identifies and returns the finite verb governing a node. If the parent is
# not a finite verb, looks for auxiliary/copula siblings.
#------------------------------------------------------------------------------
sub get_parent_finite_verb
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    return $parent if($parent->is_finite_verb());
    my @siblings = grep {$_ != $node} $parent->children();
    # Note that there may be other finite siblings that we are not interested in, such as subordinate predicates.
    my @result = grep {$_->deprel() =~ m/^(aux|aux:pass|cop)$/ && $_->is_finite_verb()} @siblings;
    my $result = scalar(@result) >= 1 ? $result[0] : undef;
    return $result;
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

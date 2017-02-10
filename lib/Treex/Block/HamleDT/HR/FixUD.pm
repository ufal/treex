package Treex::Block::HamleDT::HR::FixUD;
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
    $self->fix_relations($root);
}



#------------------------------------------------------------------------------
# Fixes known issues in lemma, tag and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        # Pronominal words.
        if($node->is_pronominal())
        {
            # Reflexive pronouns lack PronType=Prs.
            # On the other hand they have Number=Sing while they are used in plural as well.
            if($lemma eq 'sebe')
            {
                $iset->set('prontype' => 'prs', 'number' => '');
            }
            # Possessive determiners.
            elsif($lemma =~ m/^(moj|tvoj|njegov)$/)
            {
                $iset->set('pos' => 'adj', 'prontype' => 'prs', 'possnumber' => 'sing');
            }
            elsif($lemma =~ m/^(naš|vaš|njihov)$/)
            {
                $iset->set('pos' => 'adj', 'prontype' => 'prs', 'possnumber' => 'plur');
            }
            # Reflexive possessive determiners.
            elsif($lemma eq 'svoj')
            {
                $iset->set('pos' => 'adj', 'prontype' => 'prs');
            }
        }
        # Verbal copulas should be AUX and not VERB.
        if($node->is_verb() && $node->deprel() eq 'cop')
        {
            # The only copula verb is "biti".
            if($lemma ne 'biti')
            {
                log_warn("Copula verb should have lemma 'biti' but this one has '$lemma'");
            }
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



#------------------------------------------------------------------------------
# Fixes known issues in dependency relations.
#------------------------------------------------------------------------------
sub fix_relations
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # Reflexive pronouns of inherently reflexive verbs should be attached as expl:pv, not as compound (UD guideline).
        if($node->is_reflexive() && $node->deprel() eq 'compound')
        {
            $node->set_deprel('expl:pv');
        }
        ###!!! TEMPORARY HACK: THROW AWAY REMNANT BECAUSE WE CANNOT CONVERT IT.
        if($node->deprel() eq 'remnant')
        {
            $node->set_deprel('dep:remnant');
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

=item Treex::Block::HamleDT::HR::FixUD

This is a temporary block that should fix selected known problems in the Croatian UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

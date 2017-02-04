package Treex::Block::HamleDT::ZH::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_tokenization($root);
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_remnant($root);
}



#------------------------------------------------------------------------------
# There are no spaces between words in Chinese. This block makes it explicit in
# the data.
#------------------------------------------------------------------------------
sub fix_tokenization
{
    my $self = shift;
    my $root = shift;
    my $text = '';
    my @nodes = $root->get_descendants({ordered => 1});
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        $text .= $nodes[$i]->form();
        # Exception: If there is an embedded sequence of two or more words in
        # a script that uses spaces between words, the spaces will be preserved.
        if($i < $#nodes && $nodes[$i]->form() =~ m/[\p{Latin}0-9]/ && $nodes[$i+1]->form() =~ m/[\p{Latin}0-9]/)
        {
            $text .= ' ';
        }
        else
        {
            $nodes[$i]->set_no_space_after(1);
        }
    }
    $root->get_zone()->set_sentence($text);
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
        # UD Chinese 1.4 does not contain lemmas. Arguably there is little if
        # any morphology in Chinese, and lemmas will (mostly?) be identical to
        # word forms. However, it may be sometimes useful to have them explicitly
        # shown in the LEMMA column.
        my $lemma = $node->form();
        # Exception: plural pronouns formed using the suffix "們" will be lemmatized to singular.
        if($node->is_plural() && length($lemma)>1)
        {
            $lemma =~ s/們$//;
        }
        $node->set_lemma($lemma);
        # Verbal copulas should be AUX and not VERB.
        if($node->is_verb() && $node->deprel() eq 'cop')
        {
            $node->iset()->set('verbtype', 'aux');
        }
        # Interset currently destroys several Chinese-specific values of the
        # Case feature. These values are undocumented and it is questionable
        # whether they should be used like this. But we should not discard the
        # annotation until we decide how to encode it better.
        # Case=Advb
        # Case=Comp
        # Case=Rel
        # The features are still preserved in the conll/feat attribute of each
        # node. However, the Write::CoNLLU block will not take them from there.
        # The values Advb and Comp seem to only distinguish various usages of
        # particles:
        # Case=Advb
        # 地	PART	mark	64
        # 的	PART	mark	37
        # 之	PART	mark	2
        # Case=Comp
        # 的	PART	mark	1
        # 得	PART	mark	24
        # It seems more appropriate to encode them in the syntactic relation.
        my $origfeat = $node->conll_feat();
        if($origfeat =~ m/Case=Advb/)
        {
            $node->set_deprel('mark:advb');
        }
        if($origfeat =~ m/Case=Comp/)
        {
            $node->set_deprel('mark:comp');
        }
        # The feature Case=Rel is mostly used with particles that make relative
        # clauses. Their current deprel is wrong. They are attached to the head
        # verb of the relative clause, which is also acl:relcl. The particle
        # itself is a leaf and it should be either just mark, or mark:relcl.
        # Case=Rel
        # 身體	NOUN	nmod	1
        # 的	PART	acl:relcl	2366
        # 之	PART	acl:relcl	61
        # 的	PART	dep	1
        if($origfeat =~ m/Case=Rel/)
        {
            $node->set_deprel('mark:relcl');
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
# There is one sentence that uses the remnant relation. This sentence must be
# analyzed differently under UD v2.
#------------------------------------------------------------------------------
sub fix_remnant
{
    my $self = shift;
    my $root = shift;
    # 北京外城共有七門,南面三門,東西各一門,此外還有兩座便門.
    # Běijīng wài chéng gòngyǒu qī mén, nánmiàn sānmén, dōngxi gè yīmén, cǐwài hái yǒu liǎng zuò biàn mén.
    # Google Translate: Beijing outside the city a total of seven, three south, east and west each one, in addition to two side door.
    # Meaning estimated by DZ: Outer part of Beijing has a total of seven gates,
    # three of them in the south, one in the east and one in the west,
    # in addition there are two side gates.
    my @top = $root->children();
    if($self->get_node_spanstring($top[0]) =~ m/^北京 外城 共 有 七 門 , 南面 三 門 , 東西 各 一 門 , 此外 還 有 兩 座 便門 .$/)
    {
        my @subtree = $self->get_node_subtree($top[0]);
        # Subject to the first you.
        $subtree[1]->set_parent($subtree[3]);
        # Convert remnants to conjuncts + orphans.
        $subtree[6]->set_parent($subtree[7]);
        $subtree[7]->set_parent($subtree[3]);
        $subtree[7]->set_deprel('conj');
        $subtree[9]->set_parent($subtree[7]);
        $subtree[9]->set_deprel('orphan');
        $subtree[10]->set_parent($subtree[11]);
        $subtree[11]->set_parent($subtree[3]);
        $subtree[11]->set_deprel('conj');
        $subtree[14]->set_parent($subtree[11]);
        $subtree[14]->set_deprel('orphan');
        # Make the first you the root.
        $subtree[3]->set_parent($root);
        $subtree[3]->set_deprel('root');
        $subtree[18]->set_parent($subtree[3]);
        $subtree[18]->set_deprel('conj');
        $subtree[22]->set_parent($subtree[3]);
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

=item Treex::Block::HamleDT::ZH::FixUD

This is a temporary block that should fix selected known problems in the Chinese UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

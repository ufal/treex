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
    foreach my $node (@nodes)
    {
        $text .= $node->form();
        $node->set_no_space_after(1);
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
        $node->set_lemma($node->form());
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
        if($origfeat =~ m/Case=Comp/)
        {
            $node->set_deprel('mark:relcl');
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

=item Treex::Block::HamleDT::ZH::FixUD

This is a temporary block that should fix selected known problems in the Chinese UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::HamleDT::ID::FixUD;
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
        # After UD release 2.1, we generated MorphInd analysis for every word and stored it in the MISC column.
        # http://septinalarasati.com/morphind/ (Septina Dian Larasati)
        # Because it is a MISC attribute, any | and & were escaped; decode them.
        my @morphind = map {s/&vert;/|/g; s/&amp;/&/g; $_} (grep {m/^MorphInd=/} ($node->get_misc()));
        if(scalar(@morphind)>0)
        {
            $morphind[0] =~ m/^MorphInd=\^(.*)\$$/;
            my $morphind = $1;
            # Simple words have just lemma, lemma tag and POS tag:
            # ini<b>_B--
            if($morphind =~ m/^([^_]+)_(...)$/)
            {
                my $lemma = $1;
                my $tag = $2;
                # Remove lemma tags from the lemma.
                $lemma =~ s/<.>//g;
                # Remove morpheme boundaries from the lemma.
                $lemma =~ s/\+//g;
                # Uppercase lemma characters trigger morphonological changes but we don't want them in the lemma.
                # (On the other hand, we would like to have capitalized lemmas of proper nouns but we would need to look at the original form and use heuristics to achieve that.)
                $lemma = lc($lemma);
                $node->set_lemma($lemma);
                $node->set_conll_pos($tag);
            }
            else
            {
                log_warn("Unexpected MorphInd format: $morphind");
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

This is a temporary block that should fix selected known problems in the Indonesian UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

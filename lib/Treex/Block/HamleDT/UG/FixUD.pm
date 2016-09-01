package Treex::Block::HamleDT::UG::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_non_leaf_punct($root);
    $self->fix_punct_attachment($root);
    $self->convert_deprels($root);
    $self->fix_multi_root($root);
    $self->push_copula_down($root);
    $self->push_postposition_down($root);
}



#------------------------------------------------------------------------------
# Fixes punctuation nodes that are not leaves. Re-attaches their dependents to
# the next available ancestor.
#------------------------------------------------------------------------------
sub fix_non_leaf_punct
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $oparent = $node->parent();
        my $nparent = $oparent;
        while(!$nparent->is_root() && $nparent->is_punctuation())
        {
            $nparent = $nparent->parent();
        }
        if($nparent != $oparent)
        {
            $node->set_parent($nparent);
        }
    }
}



#------------------------------------------------------------------------------
# Fixes attachment of punctuation:
# 1. punctuation is not attached to ROOT unless it is the only node in the tree
# 2. punctuation attachment must respect projectivity. If there is a dependency
#    between nodes L, R, where L preceeds and R follows the punctuation symbol
#    in the sentence, the symbol must not be attached higher than L or R.
#------------------------------------------------------------------------------
sub fix_punct_attachment
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    # Get depth for each node. We will attach punctuation as high as possible.
    my @depth;
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $p = $nodes[$i]->parent();
        my $d = 1;
        while(!$p->is_root())
        {
            $p = $p->parent();
            $d++;
        }
        $depth[$i] = $d;
        # Make sure that ord()==$i+1. The code below relies on it.
        log_fatal('ord() != $i+1') if($nodes[$i]->ord() != $i+1);
    }
    # Re-attach punctuation symbols.
    my $last_non_punctuation;
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        if($nodes[$i]->is_punctuation())
        {
            # Ord should be $i+1.
            my $o = $i+1;
            # Find a candidate to the left.
            my $left;
            if(defined($last_non_punctuation))
            {
                $left = $last_non_punctuation;
                while(1)
                {
                    my $p = $left->parent();
                    last if($p->is_root() || $p->ord() > $o);
                    $left = $p;
                }
            }
            # Find a candidate to the right.
            my $next_non_punctuation;
            for(my $j = $i+1; $j<=$#nodes; $j++)
            {
                if(!$nodes[$j]->is_punctuation())
                {
                    $next_non_punctuation = $nodes[$j];
                    last;
                }
            }
            my $right;
            if(defined($next_non_punctuation))
            {
                $right = $next_non_punctuation;
                while(1)
                {
                    my $p = $right->parent();
                    last if($p->is_root() || $p->ord() < $o);
                    $right = $p;
                }
            }
            # Identify the winner.
            my $winner;
            if(defined($left) && defined($right))
            {
                # Ord should be $i+1. That's how we find the pre-computed depth.
                ###!!! But why don't we compute it here?
                my $ld = $depth[$left->ord()-1];
                my $rd = $depth[$right->ord()-1];
                # Deeper candidate wins. That should ensure that the punctuation does not create a gap in non-projective dependency.
                $winner = $rd>$ld ? $right : $left;
            }
            elsif(defined($left))
            {
                $winner = $left;
            }
            elsif(defined($right))
            {
                $winner = $right;
            }
            if(defined($winner))
            {
                # This will not create a cycle if we called fix_non_leaf_punct() first.
                $nodes[$i]->set_parent($winner);
                $nodes[$i]->set_deprel('punct');
            }
        }
        else
        {
            $last_non_punctuation = $nodes[$i];
        }
    }
}



#------------------------------------------------------------------------------
# Converts UyDT dependency relations to Universal Dependencies.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if($deprel eq 'ADV')
        {
            if($node->parent()->is_verb())
            {
                if($node->is_verb())
                {
                    $deprel = 'advcl';
                }
                elsif($node->is_noun())
                {
                    $deprel = 'nmod';
                }
                else
                {
                    $deprel = 'advmod';
                }
            }
            elsif($node->parent()->is_noun() && $node->is_adjective())
            {
                $deprel = 'amod';
            }
        }
        elsif($deprel eq 'APPOS')
        {
            $deprel = 'appos';
        }
        elsif($deprel eq 'ATT')
        {
            if($node->is_numeral())
            {
                $deprel = 'nummod';
            }
            elsif($node->is_adjective())
            {
                $deprel = 'amod';
            }
            elsif($node->is_noun())
            {
                $deprel = 'nmod';
            }
        }
        elsif($deprel eq 'AUX')
        {
            $deprel = 'aux';
            if($node->is_verb()) # it should be!
            {
                $node->iset()->set('verbtype', 'aux');
                $node->set_tag('AUX');
            }
            # Auxiliary verb does not have its own dependents. They are attached to the parent verb instead.
            my @children = $node->children();
            my $parent = $node->parent();
            unless($parent->is_root())
            {
                foreach my $child (@children)
                {
                    $child->set_parent($parent);
                }
            }
        }
        elsif($deprel eq 'CLAS')
        {
            $deprel = 'nmod:clas';
        }
        elsif($deprel eq 'COLL')
        {
            $deprel = 'compound';
        }
        # Coordination: haywanlar we ösümlüklerge: COORD(ösümlüklerge, haywanlar); CONJ(ösümlüklerge, we).
        # "we" is coordinating conjunction "and".
        elsif($deprel eq 'CONJ')
        {
            $deprel = 'cc';
        }
        elsif($deprel eq 'COORD')
        {
            $deprel = 'conj';
        }
        # Copula annotation is not consistent in the sample I have.
        # Sometimes the copula verb is the head of the clause but it is labeled COP. The previous word (substantive predicate) is attached to it:
        # COP(bolushqa/VERB, baraqsan/ADJ/advmod); "bolushqa" is a form of the "Complete Copula" "bol".
        # Sometimes the substantive predicate is attached to the copula verb, and their relation is labeled COP:
        # COP(idi/VERB, qarlighachlar/NOUN); "idi" is (I think) past tense of "Direct Judgment Copula".
        # COP(bolghini/VERB, uzatmaqchi/NOUN); "bolghini" seems to be a form of the "Complete Copula" "bol".
        elsif($deprel eq 'COP')
        {
            $deprel = 'cop';
        }
        # DAT = dative (suffix "-ga")
        elsif($deprel eq 'DAT')
        {
            $deprel = 'iobj';
        }
        elsif($deprel eq 'LOC')
        {
            if($node->is_noun() || $node->is_adjective() || $node->is_numeral())
            {
                $deprel = 'nmod:loc';
            }
        }
        elsif($deprel eq 'OBJ')
        {
            $deprel = 'dobj';
        }
        elsif($deprel eq 'POSS')
        {
            $deprel = 'nmod:poss';
        }
        # POST seems to be an argument of a postposition.
        elsif($deprel eq 'POST')
        {
            # Do nothing now. We will restructure the tree later and the node will get a new deprel then.
        }
        elsif($deprel eq 'PRED')
        {
            $deprel = 'parataxis';
        }
        elsif($deprel eq 'ROOT')
        {
            $deprel = 'root';
        }
        elsif($deprel eq 'SUBJ')
        {
            if($node->is_verb())
            {
                $deprel = 'csubj';
            }
            else
            {
                $deprel = 'nsubj';
            }
        }
        elsif($deprel eq 'void')
        {
            $deprel = 'dep';
        }
        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# Fixes multiple branches under the root node.
#------------------------------------------------------------------------------
sub fix_multi_root
{
    my $self = shift;
    my $root = shift;
    my @topnodes = $root->get_children({'ordered' => 1});
    if(scalar(@topnodes) > 1)
    {
        my $winner;
        # Prefer those with the "root" deprel.
        my @rtn = grep {$_->deprel() eq 'root'} (@topnodes);
        if(scalar(@rtn) >= 1)
        {
            $winner = pop(@rtn);
        }
        else
        {
            $winner = pop(@topnodes);
        }
        foreach my $tn (@topnodes)
        {
            unless($tn==$winner)
            {
                $tn->set_parent($winner);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Swaps positions of nominal predicate and copula.
#------------------------------------------------------------------------------
sub push_copula_down
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Copula annotation is not consistent in the sample I have.
        # Sometimes the copula verb is the head of the clause but it is labeled COP. The previous word (substantive predicate) is attached to it:
        # COP(bolushqa/VERB, baraqsan/ADJ/advmod); "bolushqa" is a form of the "Complete Copula" "bol".
        # Sometimes the substantive predicate is attached to the copula verb, and their relation is labeled COP:
        # COP(idi/VERB, qarlighachlar/NOUN); "idi" is (I think) past tense of "Direct Judgment Copula".
        # COP(bolghini/VERB, uzatmaqchi/NOUN); "bolghini" seems to be a form of the "Complete Copula" "bol".
        if($node->deprel() eq 'cop')
        {
            my $parent = $node->parent();
            if($node->is_noun() && $parent->is_verb())
            {
                $node->set_parent($parent->parent());
                $node->set_deprel($parent->deprel());
                $parent->set_parent($node);
                $parent->set_deprel('cop');
                my @children = $parent->children();
                foreach my $child (@children)
                {
                    $child->set_parent($node);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Swaps positions of noun/verb and postposition.
#------------------------------------------------------------------------------
sub push_postposition_down
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # POST seems to be an argument of a postposition.
        if($node->deprel() eq 'POST')
        {
            my $parent = $node->parent();
            my $postposition = $parent;
            if($node->is_verb() && ($parent->is_adposition() || $parent->is_conjunction() || $parent->is_noun() && $parent->deprel() eq 'nmod:loc'))
            {
                # The original tag set does not distinguish CONJ and SCONJ but now we know that this is a subordinating conjunction.
                if($parent->is_conjunction())
                {
                    $parent->iset()->set('conjtype', 'sub');
                    $parent->set_tag('SCONJ');
                }
                if($postposition->deprel() =~ m/^(advmod|nmod:loc)$/)
                {
                    $node->set_deprel('advcl');
                }
                $node->set_parent($postposition->parent());
                $postposition->set_parent($node);
                $postposition->set_deprel('mark');
            }
            elsif($node->is_noun() && $parent->is_adposition())
            {
                if($postposition->deprel() =~ m/^(advmod|nmod:loc)$/)
                {
                    $node->set_deprel('nmod');
                }
                $node->set_parent($postposition->parent());
                $postposition->set_parent($node);
                $postposition->set_deprel('case');
            }
            # The postposition is a function word and should have no dependents of its own (except for multi-word expressions and coordinations).
            foreach my $child ($postposition->children())
            {
                $child->set_parent($node);
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

=item Treex::Block::HamleDT::UG::FixUD

This is a conversion block that takes a file of the Uyghur Treebank, partially converted to UD,
and does the rest of the conversion.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

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
    $self->fix_pos($root);
    $self->fix_non_leaf_punct($root);
    $self->fix_punct_attachment($root);
    $self->convert_deprels($root);
    # Since 9.9.2016, I am working with data preprocessed by Marhaba's rules.
    # I am thus assuming that copula has been re-attached down and I am not re-attaching it back.
    #$self->push_copula_down($root);
    $self->push_postposition_down($root);
    # Do this at the end. It also makes sure that the top node is attached as 'root' (even if it has been moved from elsewhere).
    $self->fix_multi_root($root);
}



#------------------------------------------------------------------------------
# Fixes POS tags.
#------------------------------------------------------------------------------
sub fix_pos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        if($form =~ m/^\pP+$/ && !$node->is_punctuation() && !$node->is_symbol())
        {
            $node->iset()->set_hash({'pos' => 'punc'});
            $node->set_tag('PUNCT');
        }
        elsif($form !~ m/^\pP+$/ && $node->is_punctuation())
        {
            $node->iset()->set_hash({});
            $node->set_tag('X');
        }
    }
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
        # Input may have contained cycles. After decyclization the deprels may contain traces but that does not help us now.
        $deprel =~ s/-CYCLE.*$//;
        # locative case
        if($deprel eq 'ABL')
        {
            # non-finite verb in ablative case
            if($node->is_verb())
            {
                $deprel = 'advcl';
            }
            else
            {
                $deprel = 'nmod:abl';
            }
        }
        elsif($deprel =~ m/^(ADJMOD|ATT)$/)
        {
            if($node->is_numeral())
            {
                $deprel = 'nummod';
            }
            elsif($node->is_adjective())
            {
                $deprel = 'amod';
            }
            elsif($node->is_noun() || $node->is_adverb()) # "adverb" was in fact locative noun
            {
                $deprel = 'nmod';
            }
            elsif($node->is_verb())
            {
                $deprel = 'acl';
            }
            else # X
            {
                $deprel = 'nmod';
            }
        }
        elsif($deprel =~ m/^ADV(MOD)?$/)
        {
            my $parent = $node->parent();
            if($parent->is_adposition())
            {
                # Only fix the original deprel now. It will be restructured later.
                $deprel = 'POST';
            }
            elsif($parent->is_noun())
            {
                if($node->is_noun())
                {
                    $deprel = 'nmod';
                }
                elsif($node->is_adjective())
                {
                    $deprel = 'amod';
                }
                elsif($node->is_verb())
                {
                    $deprel = 'acl';
                }
                else
                {
                    $deprel = 'advmod:emph';
                }
            }
            else # parent is probably verb, adjective or adverb
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
        }
        elsif($deprel eq 'ADVCL')
        {
            $deprel = 'advcl';
        }
        elsif($deprel eq 'APPOS')
        {
            $deprel = 'appos';
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
        # "CL" may be "clause"? Examples look like coordinate clauses attached to the head of the last clause.
        elsif($deprel eq 'CL')
        {
            $deprel = 'conj';
        }
        elsif($deprel eq 'CLAS')
        {
            $deprel = 'nmod:clas';
        }
        elsif($deprel eq 'COLL')
        {
            $deprel = 'compound';
        }
        # COM = comparison. The "standard" that something is compared to is typically a noun phrase in ablative case and is attached to the quality as COM.
        elsif($deprel eq 'COM')
        {
            $deprel = 'nmod:cmp';
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
        elsif($deprel eq 'DET')
        {
            $deprel = 'det';
        }
        # ETOL = reduplicative
        # However, there is a whole chain and not all members reduplicate the previous ones. All but the punctuation symbols are chained using ETOL:
        # tëshi pal - pal , ichi ghal - ghal
        elsif($deprel eq 'ETOL')
        {
            $deprel = 'dep';
        }
        # IND = independent
        # It often denotes vocative noun phrases, delimited by commas: apa (mother/sister), balilar (children), aqsaqal (elders).
        # Sometimes it also labels a short imperative phrase, e.g. ëling (take something to eat).
        elsif($deprel eq 'IND')
        {
            if($node->is_noun())
            {
                $deprel = 'vocative';
            }
            else
            {
                $deprel = 'discourse';
            }
        }
        # instrumental case
        elsif($deprel eq 'INST')
        {
            # non-finite verb in instrumental case
            if($node->is_verb())
            {
                $deprel = 'advcl';
            }
            # INST is normally a nominal in instrumental case but since the tags were predicted automatically, there are tagging errors and it can be anything.
            else
            {
                $deprel = 'nmod:ins';
            }
        }
        # locative case
        elsif($deprel eq 'LOC')
        {
            if($node->is_adverb())
            {
                $deprel = 'advmod';
            }
            # non-finite verb in locative case, e.g. këliwatqanda
            elsif($node->is_verb())
            {
                $deprel = 'advcl';
            }
            # LOC is normally a nominal in locative case but since the tags were predicted automatically, there are tagging errors and it can be anything.
            else
            {
                $deprel = 'nmod:loc';
            }
        }
        elsif($deprel eq 'OBJ')
        {
            $deprel = 'dobj';
        }
        elsif($deprel eq 'OTHER')
        {
            $deprel = 'dep';
        }
        elsif($deprel eq 'POSS')
        {
            $deprel = 'nmod:poss';
        }
        # POST seems to be an argument of a postposition.
        elsif($deprel eq 'POST')
        {
            # Do nothing now. We will restructure the tree later and the node will get a new deprel then.
            # Only if we do not plan on restructuring, change the label now.
            # VERB on VERB – perhaps an error? Example: "qalay.VERB.POST dëgen.VERB.acl"
            if($node->parent()->is_verb())
            {
                if($node->is_verb())
                {
                    $deprel = 'ccomp';
                }
                elsif($node->is_adverb() || $node->is_adjective())
                {
                    $deprel = 'advmod';
                }
                # The tagset does not distinguish coordinating and subordinating conjunctions but the examples I saw seemed to be coordinated.
                elsif($node->is_conjunction())
                {
                    $deprel = 'cc';
                }
                elsif($node->is_adposition() || $node->is_particle())
                {
                    $deprel = 'mark';
                }
            }
        }
        # PRED denotes the subject in clauses with nominal predicate (with or without copula).
        elsif($deprel eq 'PRED')
        {
            $deprel = 'nsubj:cop';
        }
        elsif($deprel eq 'QNTMOD')
        {
            $deprel = 'nummod';
        }
        elsif($deprel eq 'QUOT')
        {
            $deprel = 'parataxis';
        }
        elsif($deprel eq 'ROOT')
        {
            $deprel = 'root';
        }
        # SENT was used in older versions of the data and should not appear any more.
        elsif($deprel eq 'SENT')
        {
            $deprel = 'parataxis';
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
        elsif($deprel eq 'SUBSENT')
        {
            $deprel = 'advcl';
        }
        # VOC is vocative but it is now probably replaced by IND (occurs in an old version of the data, only a few times).
        # Example: "qedirlik lale, ..." = "Dear Lale, ..."; lale is attached to the main predicate as VOC.
        elsif($deprel eq 'VOC')
        {
            $deprel = 'vocative';
        }
        elsif($deprel eq 'void')
        {
            $deprel = 'dep';
        }
        $node->set_deprel($deprel);
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
            my $moved = 0;
            # Postposition can be also noun in locative, e.g. "halda". Not all are marked as nmod:loc; some are only nmod.
            # The parent tag may be unknown ('X') and we should not choke on that.
            my $parent_ok = ($parent->is_adposition() || $parent->is_conjunction() || $parent->is_particle() || $parent->is_adverb() || $parent->is_noun() || $parent->iset()->pos() eq '');
            if($node->is_verb() && $parent_ok)
            {
                # The original tag set does not distinguish CONJ and SCONJ but now we know that this is a subordinating conjunction.
                if($parent->is_conjunction())
                {
                    $parent->iset()->set('conjtype', 'sub');
                    $parent->set_tag('SCONJ');
                }
                $node->set_parent($postposition->parent());
                $node->set_deprel('advcl');
                $postposition->set_parent($node);
                $postposition->set_deprel('mark');
                $moved = 1;
            }
            elsif($parent_ok)
            {
                $node->set_parent($postposition->parent());
                $node->set_deprel('nmod');
                $postposition->set_parent($node);
                $postposition->set_deprel('case');
                $moved = 1;
            }
            # If the parent is not postposition, there is probably an annotation error. Turn the node into a common modifier.
            elsif($node->is_noun())
            {
                $node->set_deprel('nmod');
            }
            # The postposition is a function word and should have no dependents of its own (except for multi-word expressions and coordinations).
            if($moved)
            {
                foreach my $child ($postposition->children())
                {
                    $child->set_parent($node);
                }
            }
        }
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
        # Make sure the winner has the required label 'root'.
        $winner->set_deprel('root');
    }
    elsif(scalar(@topnodes)==1)
    {
        $topnodes[0]->set_deprel('root');
    }
    # We also do not allow the 'root' label anywhere else in the tree.
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if(!$node->parent()->is_root() && $node->deprel() eq 'root')
        {
            $node->set_deprel('dep');
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

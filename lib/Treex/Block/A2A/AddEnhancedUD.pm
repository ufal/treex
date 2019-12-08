package Treex::Block::A2A::AddEnhancedUD;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # We assume that the basic tree has been copied to the enhanced graph
    # (see the block A2A::CopyBasicToEnhanced). The enhanced graph is stored
    # in the wild attributes of nodes. Each node should now have the wild
    # attribute 'enhanced', which is a list of pairs, where each pair contains:
    # - the ord of the parent node
    # - the type of the relation between the parent node and this node
    # We do not store the Perl reference to the parent node in order to prevent cyclic references and issues with garbage collection.
    my @nodes = $root->get_descendants({'ordered' => 1});
    # First enhance all oblique relations with case information. If we later
    # copy those relations in other transformations, we want to be sure that
    # it all have been enhanced.
    foreach my $node (@nodes)
    {
        if(!exists($node->wild()->{enhanced}))
        {
            log_fatal("The wild attribute 'enhanced' does not exist.");
        }
        $self->add_enhanced_case_deprel($node); # call this before coordination and relative clauses
    }
    # Process all relations affected by relative clauses before proceeding to the next enhancement type.
    foreach my $node (@nodes)
    {
        $self->add_enhanced_relative_clause($node); # calling this before coordination has advantages but calling it after coordination might have other advantages (if we looked at the enhanced graph when doing relative clauses)
    }
    # Process all relations that shall be propagated across coordination.
    foreach my $node (@nodes)
    {
        $self->add_enhanced_parent_of_coordination($node);
        $self->add_enhanced_shared_dependent_of_coordination($node);
    }
}



#------------------------------------------------------------------------------
# Adds case information to selected relation types. This function should be
# called before we propagate dependencies across coordination, as some of the
# labels that we enhance here will be later copied to new dependencies. For the
# same reason this function should be also called before adding relations back
# from a relative clause to the modified nominal. Interaction with gapping is
# less clear. The gapping-resolving algorithm will tell us that an orphan is
# "obl" or "advcl", but its case information may actually differ from that
# found at the overtly represented predicate.
#------------------------------------------------------------------------------
sub add_enhanced_case_deprel
{
    my $self = shift;
    my $node = shift;
    foreach my $edep (@{$node->wild()->{enhanced}})
    {
        my $eparent = $edep->[0];
        my $edeprel = $edep->[1];
        # The guidelines allow enhancing nmod, acl, obl and advcl.
        # If it makes sense in the language, core relations obj, iobj and ccomp can be enhanced too.
        # Sebastian's enhancer further enhances conj relations with the lemma of the conjunction, but it is not supported in the guidelines.
        next unless($edeprel =~ m/^(nmod|acl|obl|advcl)(:|$)/);
        # Collect case and mark children. We are modifying the enhanced deprel
        # but we look for input solely in the basic tree.
        ###!!! That means that we may not be able to find a preposition shared by conjuncts.
        ###!!! Finding it would need more work anyways, because we call this function before we propagate dependencies across coordination.
        my @children = $node->children({'ordered' => 1});
        my @casemark = grep {$_->deprel() =~ m/^(case|mark)(:|$)/} (@children);
        # If the current constituent is a clause, take mark dependents but not case dependents.
        # This may not work the same way in all languages, as e.g. in Swedish Joakim uses case even with clauses.
        # However, in Czech-PUD this will help us to skip prepositions under a nominal predicate, which modify the nominal but not the clause:
        # "kandidáta, který byl v pořadí za ním" ("candidate who was after him"): avoid the preposition "za"
        if($edeprel =~ m/^(acl|advcl)(:|$)/)
        {
            @casemark = grep {$_->deprel() !~ m/^case(:|$)/} (@casemark);
        }
        # For each of the markers check whether it heads a fixed expression.
        my @cmlemmas = grep {defined($_)} map
        {
            my $x = $_;
            my @fixed = grep {$_->deprel() =~ m/^(fixed)(:|$)/} ($x->children({'ordered' => 1}));
            my $l = lc($x->lemma());
            if(defined($l) && ($l eq '' || $l eq '_'))
            {
                $l = undef;
            }
            if(defined($l))
            {
                $l = lc($l);
                if(scalar(@fixed) > 0)
                {
                    $l .= '_' . join('_', map {lc($_->lemma())} (@fixed));
                }
            }
            $l;
        }
        (@casemark);
        my $cmlemmas = join('_', @cmlemmas);
        # Only selected characters are allowed in lemmas of case markers.
        # For example, digits and punctuation symbols (except underscore) are not allowed.
        $cmlemmas =~ s/[^\p{Ll}\p{Lm}\p{Lo}\p{M}_]//g;
        $cmlemmas =~ s/^_+//;
        $cmlemmas =~ s/_+$//;
        $cmlemmas =~ s/_+/_/g;
        $cmlemmas = undef if($cmlemmas eq '');
        if(defined($cmlemmas))
        {
            $edeprel .= ":$cmlemmas";
        }
        # Look for morphological case only if this is a nominal and not a clause.
        if($edeprel =~ m/^(nmod|obl)(:|$)/)
        {
            # In Slavic and some other languages, the case of a quantified phrase may
            # be determined by the quantifier rather than by the quantified head noun.
            # We can recognize such quantifiers by the relation nummod:gov or det:numgov.
            my @qgov = grep {$_->deprel() =~ m/^(nummod:gov|det:numgov)$/} (@children);
            my $qgov = scalar(@qgov);
            # There is probably just one quantifier. We do not have any special rule
            # for the possibility that there are more than one.
            my $caseiset = $qgov ? $qgov[0]->iset() : $node->iset();
            my $case = $caseiset->case();
            if(ref($case) eq 'ARRAY')
            {
                $case = $case->[0];
            }
            if(defined($case) && $case ne '')
            {
                $edeprel .= ':'.lc($case);
            }
        }
        # Store the modified enhanced deprel back to the wild attributes.
        $edep->[1] = $edeprel;
    }
}



#------------------------------------------------------------------------------
# Transforms the enhanced dependencies between a relative clause, its
# relativizer, and the modified noun.
#
# Interactions with propagation of dependencies across coordination:
# If we do relative clauses before coordination:
# * coordinate parent nominals: new incoming (nsubj/obj/...) and outgoing (ref)
#   edges will be later propagated to/from the other conjuncts. We actually
#   do not know whether the relative clause is shared among the conjuncts. If
#   it is, then we should mark the relevant nodes as shared dependents.
# * coordinate relative clauses: the second clause does not know it is a
#   relative clause, so it does nothing.
# If we do relative clauses after coordination:
# * if the relative clause is shared among coordinate parent nominals, by now
#   we have a separate acl:relcl dependency to each of them. And if we actually
#   look at the enhanced graph (which we currently don't, we look at the basic
#   graph), we will get all the transformations.
# * coordinate relative clauses: we could transform each of them and the parent
#   nominal could even have a different function in each of them. If they share
#   the relativizer, we could see it as well.
# * problem: we use the wild attribute 'relativizer'; while the coordination
#   enhancement copied the relation acl:relcl, it did not touch this attribute.
#------------------------------------------------------------------------------
sub add_enhanced_relative_clause
{
    my $self = shift;
    my $node = shift;
    ###!!! We should take input from the enhanced graph when it already has
    ###!!! dependencies propagated across coordination. There could be
    ###!!! coordinate relative clauses and they may or may not share the
    ###!!! relativizer. The modified noun can be also coordinate and then we
    ###!!! should link to all conjuncts (or do this relative clause enhancement
    ###!!! first and leave the rest on the conjunct propagation).
    return unless($node->deprel() eq 'acl:relcl' && exists($node->wild()->{'relativizer'}));
    my @relativizers = grep {$_->ord() == $node->wild()->{'relativizer'}} ($node->get_descendants({'add_self' => 1}));
    return unless(scalar(@relativizers) > 0);
    my $relativizer = $relativizers[0];
    my $relparent = $relativizer->parent();
    my $reldeprel = $self->get_first_edeprel_to_parent_n($relativizer, $relparent->ord());
    # We refer to the parent of the clause as the modified $noun, although it may be a pronoun.
    my $noun = $node->parent();
    # Add an enhanced relation 'ref' from the modified noun to the relativizer.
    push(@{$relativizer->wild()->{enhanced}}, [$noun->ord(), 'ref']);
    # If the relativizer is the root of the relative clause, there is no other
    # node in the relative clause from which a new relation should go to the
    # modified noun. However, the relative clause has a nominal predicate,
    # which corefers with the modified noun, and we can draw a new relation
    # from the modified noun to the subject of the relative clause.
    if($relativizer == $node)
    {
        my @subjects = grep {$_->deprel() =~ m/^[nc]subj(:|$)/} ($node->children());
        foreach my $subject (@subjects)
        {
            push(@{$subject->wild()->{enhanced}}, [$noun->ord(), $subject->deprel()]);
        }
    }
    # If the relativizer is not the root of the relative clause, we remove its
    # current relation to its current and instead we add an analogous relation
    # between the parent and the modified noun.
    else
    {
        my @relenhanced = grep {$_->[0] != $relparent->ord()} (@{$relativizer->wild()->{enhanced}});
        $relativizer->wild()->{enhanced} = \@relenhanced;
        # Even if the relativizer is adverb or determiner, the new dependent will be noun or pronoun.
        $reldeprel =~ s/^advmod(:|$)/obl$1/;
        $reldeprel =~ s/^det(:|$)/nmod$1/;
        push(@{$noun->wild()->{enhanced}}, [$relparent->ord(), $reldeprel]);
    }
}



#------------------------------------------------------------------------------
# Propagates parent of coordination to all conjuncts.
#------------------------------------------------------------------------------
sub add_enhanced_parent_of_coordination
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() =~ m/^conj(:|$)/)
    {
        # Find the nearest non-conj ancestor, i.e., the first conjunct.
        my $inode = $node->parent();
        while(defined($inode))
        {
            last if($inode->deprel() !~ m/^conj(:|$)/);
            $inode = $inode->parent();
        }
        if(defined($inode) && defined($inode->parent()) && $inode->deprel() !~ m/^conj(:|$)/)
        {
            # Although we mostly look at the basic tree for input, we must copy
            # the deprel from the enhanced graph because it may have been enhanced
            # with case information.
            my $edeprel = $self->get_first_edeprel_to_parent_n($inode, $inode->parent()->ord());
            push(@{$node->wild()->{enhanced}}, [$inode->parent()->ord(), $edeprel]);
            # The coordination may function as a shared dependent of other coordination.
            # In that case, make me depend on every conjunct in the parent coordination.
            if($inode->is_shared_modifier())
            {
                my @conjuncts = $self->recursively_collect_conjuncts($inode->parent());
                foreach my $conjunct (@conjuncts)
                {
                    push(@{$node->wild()->{enhanced}}, [$conjunct->ord(), $edeprel]);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Propagates shared dependent of coordination to all conjuncts.
#------------------------------------------------------------------------------
sub add_enhanced_shared_dependent_of_coordination
{
    my $self = shift;
    my $node = shift;
    # Exclude shared "modifiers" whose deprel is 'cc'. They probably just help
    # delimit the coordination. (In nested coordination "A - B and C - D", the
    # conjunction 'and' would come out as a shared 'cc' dependent of 'C' and 'D'.)
    # Note: If the shared dependent itself is coordination, all conjuncts
    # should have the flag is_shared_modifier. (At least I have now checked
    # that there are nodes that have the flag and their deprel is 'conj'.
    # Of course that is not a proof that it happens always when it should.)
    # In that case, the parent is the first conjunct, and the effective parent
    # lies one or more levels further up. However, we solve this in the
    # function add_enhanced_parent_of_coordination(). Therefore, we do nothing
    # for non-first conjuncts in coordinate shared dependents here.
    if($node->is_shared_modifier())
    {
        # Get all suitable incoming enhanced relations.
        my @iedges = grep {$_->[1] !~ m/^(conj|cc|punct)(:|$)/} ($self->get_enhanced_deps($node));
        foreach my $iedge (@iedges)
        {
            my $parent = $self->get_node_by_ord($node, $iedge->[0]);
            my $edeprel = $iedge->[1];
            my @conjuncts = $self->recursively_collect_conjuncts($parent);
            foreach my $conjunct (@conjuncts)
            {
                push(@{$node->wild()->{enhanced}}, [$conjunct->ord(), $edeprel]);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Returns the list of conj children of a given node. If there is nested
# coordination, returns the nested conjuncts too.
#------------------------------------------------------------------------------
sub recursively_collect_conjuncts
{
    my $self = shift;
    my $node = shift;
    my $visited = shift;
    # Keep track of visited nodes. Avoid endless loops.
    my @_dummy;
    if(!defined($visited))
    {
        $visited = \@_dummy;
    }
    return () if($visited->[$node->ord()]);
    $visited->[$node->ord()]++;
    my @echildren = $self->get_enhanced_children($node);
    my @conjuncts = grep {my $x = $_; any {$_->[0] == $node->ord() && $_->[1] =~ m/^conj(:|$)/} ($self->get_enhanced_deps($x))} (@echildren);
    my @conjuncts2;
    foreach my $c (@conjuncts)
    {
        my @c2 = $self->recursively_collect_conjuncts($c, $visited);
        if(scalar(@c2) > 0)
        {
            push(@conjuncts2, @c2);
        }
    }
    return (@conjuncts, @conjuncts2);
}



#------------------------------------------------------------------------------
# Returns the list of incoming enhanced edges for a node. Each element of the
# list is a pair: 1. ord of the parent node; 2. relation label.
#------------------------------------------------------------------------------
sub get_enhanced_deps
{
    my $self = shift;
    my $node = shift;
    my $wild = $node->wild();
    if(!exists($wild->{enhanced}) || !defined($wild->{enhanced}) || ref($wild->{enhanced}) ne 'ARRAY')
    {
        log_fatal("Wild attribute 'enhanced' does not exist or is not an array reference.");
    }
    return @{$wild->{enhanced}};
}



#------------------------------------------------------------------------------
# Finds a node with a given ord in the same tree. This is useful if we are
# looking at the list of incoming enhanced edges and need to actually access
# one of the parents listed there by ord. We assume that if the method is
# called, the caller is confident that the node should exist. The method will
# throw an exception if there is no node or multiple nodes with the given ord.
#------------------------------------------------------------------------------
sub get_node_by_ord
{
    my $self = shift;
    my $node = shift; # some node in the same tree
    my $ord = shift;
    my @results = grep {$_->ord() == $ord} ($node->get_root()->get_descendants());
    if(scalar(@results) == 0)
    {
        log_fatal("No node with ord '$ord' found.");
    }
    if(scalar(@results) > 1)
    {
        log_fatal("There are multiple nodes with ord '$ord'.");
    }
    return $results[0];
}



#------------------------------------------------------------------------------
# Returns the list of children of a node in the enhanced graph, i.e., the list
# of nodes that have at least one incoming edge from the given start node.
# The list is ordered by their ord value.
#------------------------------------------------------------------------------
sub get_enhanced_children
{
    my $self = shift;
    my $node = shift;
    # We do not maintain an up-to-date list of outgoing enhanced edges, only
    # the incoming ones. Therefore we must search all nodes of the sentence.
    my @nodes = $node->get_root()->get_descendants({'ordered' => 1});
    my @children;
    foreach my $n (@nodes)
    {
        my @edeps = $self->get_enhanced_deps($n);
        if(any {$_->[0] == $node->ord()} (@edeps))
        {
            push(@children, $n);
        }
    }
    return @children;
}



#------------------------------------------------------------------------------
# Returns the relation from a node to parent with ord N. Returns the first
# relation if there are multiple relations to the same parent (this method is
# intended only for situations where we are confident that there is exactly one
# such relation). Throws an exception if the wild attribute 'enhanced' does not
# exist or if there is no relation to the given parent.
#------------------------------------------------------------------------------
sub get_first_edeprel_to_parent_n
{
    my $self = shift;
    my $node = shift;
    my $parentord = shift;
    my @edeps = $self->get_enhanced_deps($node);
    my @edges_from_n = grep {$_->[0] == $parentord} (@edeps);
    if(scalar(@edges_from_n) == 0)
    {
        log_fatal("No relation to parent with ord '$parentord' found.");
    }
    return $edges_from_n[0][1];
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::AddEnhancedUD

=head1 DESCRIPTION

In Universal Dependencies, there is basic and enhanced representation. The
basic representation is a tree and corresponds to the a-tree in Treex. The
enhanced representation is a directed graph and can be optionally stored in
wild attributes of individual nodes (there is currently no API for the
enhanced structure).

This block adds the enhancements defined in the UD v2 guidelines based on the
basic dependencies. The block must be called after the basic dependencies have
been copied to the enhanced graph (see the block CopyBasicToEnhancedUD). It is
important because here we access multiple nodes from one process_node() method
and we need to be sure that all the other nodes already have their enhanced
attribute.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018, 2019 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

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
#   look at the enhanced graph, we will get all the transformations.
# * coordinate relative clauses: we could transform each of them and the parent
#   nominal could even have a different function in each of them. If they share
#   the relativizer, we could see it as well.
#------------------------------------------------------------------------------
sub add_enhanced_relative_clause
{
    my $self = shift;
    my $node = shift;
    # This node is the root of a relative clause if at least one of its parents
    # is connected via the acl:relcl relation. We refer to the parent of the
    # clause as the modified $noun, although it may be a pronoun.
    my @nouns = $self->get_enhanced_parents($node, '^acl:relcl(:|$)');
    return if(scalar(@nouns)==0);
    my @relativizers = sort {$a->ord() <=> $b->ord()}
    (
        grep {$_->ord() <= $node->ord() && $_->is_relative()}
        (
            $node,
            $self->get_enhanced_descendants($node)
        )
    );
    return unless(scalar(@relativizers) > 0);
    ###!!! Assume that the leftmost relativizer is the one that relates to the
    ###!!! current relative clause. This is an Indo-European bias.
    my $relativizer = $relativizers[0];
    my @edeps = $self->get_enhanced_deps($relativizer);
    # All relations other than 'ref' will be copied to the noun.
    my @noundeps = grep {$_->[1] ne 'ref'} (@edeps);
    foreach my $noun (@nouns)
    {
        # Add an enhanced relation 'ref' from the modified noun to the relativizer.
        $self->add_enhanced_dependency($relativizer, $noun, 'ref');
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
                $self->add_enhanced_dependency($subject, $noun, $subject->deprel());
            }
        }
        # If the relativizer is not the root of the relative clause, we remove its
        # current relation to its current and instead we add an analogous relation
        # between the parent and the modified noun.
        else
        {
            foreach my $nd (@noundeps)
            {
                my $relparent = $nd->[0];
                my $reldeprel = $nd->[1];
                # Even if the relativizer is adverb or determiner, the new dependent will be noun or pronoun.
                $reldeprel =~ s/^advmod(:|$)/obl$1/;
                $reldeprel =~ s/^det(:|$)/nmod$1/;
                $self->add_enhanced_dependency($noun, $self->get_node_by_ord($node, $relparent), $reldeprel);
            }
        }
    }
    # Now that the non-ref relations have been copied to all nouns, we can
    # remove them from the relativizer. But do not do this if the relativizer
    # is the head of the relative clause! Then the incoming edges are acl:relcl
    # and we want to keep them!
    if($relativizer != $node)
    {
        # We must refresh @edeps because at the time we got it, it did not
        # contain the 'ref' relations yet.
        @edeps = $self->get_enhanced_deps($relativizer);
        my @reldeps = grep {$_->[1] eq 'ref'} (@edeps);
        $relativizer->wild()->{enhanced} = \@reldeps;
    }
}



#------------------------------------------------------------------------------
# Looks for an external, grammatically coreferential subject of an open clausal
# complement (xcomp). Adds a subject relation if it finds it.
#
# Interactions with propagation of dependencies across coordination:
# If we do external subjects after coordination:
# * if the source argument for the subject is coordination (as in "John and
#   Mary wanted to do it"), by now we have a separate nsubj relation to each of
#   the conjuncts, and we can copy each of them as an xsubj.
# * if the control verb is coordination with a shared subject (as in "John
#   promised and succeeded to do it"), nothing new happens because we have the
#   xsubj relation from "do" to "John" anyway. However, if the conjuncts share
#   the xcomp but not the subject (as in "John promised and Mary succeeded to
#   do it"), we can now draw an xsubj from "do" to both "John" and "Mary".
# * if the controlled complement is coordination (as in "John promised to come
#   and clean up"), we can draw an xsubj from each of them.
# If we do external subjects before coordination:
# * an xsubj shared among coordinate xcomps could still be multiplied but only
#   if we mark it as a shared dependent when drawing the first xsubj.
# * coordinate control verbs with private control arguments will not propagate
# * coordinate control arguments will propagate via shared parent.
#------------------------------------------------------------------------------
sub add_enhanced_external_subject
{
    my $self = shift;
    my $node = shift;
}



#------------------------------------------------------------------------------
# Propagates parent of coordination to all conjuncts.
#------------------------------------------------------------------------------
sub add_enhanced_parent_of_coordination
{
    my $self = shift;
    my $node = shift;
    my @edeps = $self->get_enhanced_deps($node);
    if(any {$_->[1] =~ m/^conj(:|$)/} (@edeps))
    {
        my @edeps_to_propagate;
        # Find the nearest non-conj ancestor, i.e., the first conjunct.
        my @eparents = $self->get_enhanced_parents($node, '^conj(:|$)');
        # There should be normally at most one conj parent for any node. So we take the first one and assume it is the only one.
        log_fatal("Did not find the 'conj' enhanced parent.") if(scalar(@eparents) == 0);
        my $inode = $eparents[0];
        while(defined($inode))
        {
            @eparents = $self->get_enhanced_parents($inode, '^conj(:|$)');
            if(scalar(@eparents) == 0)
            {
                # There are no higher conj parents. So we will now look for the non-conj parents. Those are the relations we want to propagate.
                @edeps_to_propagate = grep {$_->[1] !~ m/^conj(:|$)/} ($self->get_enhanced_deps($inode));
                last;
            }
            $inode = $eparents[0];
        }
        if(defined($inode))
        {
            foreach my $edep (@edeps_to_propagate)
            {
                $self->add_enhanced_dependency($node, $self->get_node_by_ord($node, $edep->[0]), $edep->[1]);
                # The coordination may function as a shared dependent of other coordination.
                # In that case, make me depend on every conjunct in the parent coordination.
                if($inode->is_shared_modifier())
                {
                    my @conjuncts = $self->recursively_collect_conjuncts($self->get_node_by_ord($node, $edep->[0]));
                    foreach my $conjunct (@conjuncts)
                    {
                        $self->add_enhanced_dependency($node, $conjunct, $edep->[1]);
                    }
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
                $self->add_enhanced_dependency($node, $conjunct, $edeprel);
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
# Adds a new enhanced edge incoming to a node, unless the same relation with
# the same parent already exists.
#------------------------------------------------------------------------------
sub add_enhanced_dependency
{
    my $self = shift;
    my $child = shift;
    my $parent = shift;
    my $deprel = shift;
    my $pord = $parent->ord();
    my @edeps = $self->get_enhanced_deps($child);
    unless(any {$_->[0] == $pord && $_->[1] eq $deprel} (@edeps))
    {
        push(@{$child->wild()->{enhanced}}, [$pord, $deprel]);
    }
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
    return $node->get_root() if($ord == 0);
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
# Returns the list of parents of a node in the enhanced graph, i.e., the list
# of nodes from which there is at least one edge incoming to the given node.
# The list is ordered by their ord value.
#
# Optionally the parents will be filtered by regex on relation type.
#------------------------------------------------------------------------------
sub get_enhanced_parents
{
    my $self = shift;
    my $node = shift;
    my $relregex = shift;
    my $negate = shift; # return parents that do not match $relregex
    my @edeps = $self->get_enhanced_deps($node);
    if(defined($relregex))
    {
        if($negate)
        {
            @edeps = grep {$_->[1] !~ m/$relregex/} (@edeps);
        }
        else
        {
            @edeps = grep {$_->[1] =~ m/$relregex/} (@edeps);
        }
    }
    # Remove duplicates.
    my %epmap; map {$epmap{$_->[0]}++} (@edeps);
    my @parents = sort {$a->ord() <=> $b->ord()} (map {$self->get_node_by_ord($node, $_)} (keys(%epmap)));
    return @parents;
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
# Returns the list of nodes to which there is a path from the current node in
# the enhanced graph.
#------------------------------------------------------------------------------
sub get_enhanced_descendants
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
    my @echildren2;
    foreach my $ec (@echildren)
    {
        my @ec2 = $self->get_enhanced_descendants($ec, $visited);
        if(scalar(@ec2) > 0)
        {
            push(@echildren2, @ec2);
        }
    }
    # Unlike the method Node::get_descendants(), we currently do not support
    # the parameters add_self, ordered, preceding_only etc. The caller has
    # to take care of sort and grep themselves. (We could do sorting but it
    # would be inefficient to do it in each step of the recursion. And in any
    # case we would not know whether to add self or not; if yes, then the
    # sorting would have to be repeated again.)
    #my @result = sort {$a->ord() <=> $b->ord()} (@echildren, @echildren2);
    my @result = (@echildren, @echildren2);
    return @result;
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

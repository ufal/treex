package Treex::Block::A2A::CopyBasicToEnhancedUD;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $wild = $node->wild();
    # $wild->{enhanced} is a list of pairs, where each pari contains:
    # - the ord of the parent node
    # - the type of the relation between the parent node and this node
    # We do not store the Perl reference to the parent node in order to prevent cyclic references and issues with garbage collection.
    my $parent = 0;
    if(defined($node->parent()) && defined($node->parent()->ord()))
    {
        $parent = $node->parent()->ord();
    }
    my $deprel = $node->deprel();
    my @deps = ();
    push(@deps, [$parent, $deprel]);
    # We assume that $wild->{enhanced} does not exist yet. If it does, we overwrite it!
    $wild->{enhanced} = \@deps;
    ###!!! This should later go to its own block.
    $self->add_enhanced_case_deprel($node); # call this before coordination and relative clauses
    $self->add_enhanced_relative_clause($node); # calling this before coordination has advantages but calling it after coordination might have other advantages (if we looked at the enhanced graph when doing relative clauses)
    $self->add_enhanced_parent_of_coordination($node);
    $self->add_enhanced_shared_dependent_of_coordination($node);
}



###!!! This should later go to its own block.
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
            my $edeprel = $inode->deprel();
            my @edeprels = map {$_->[1]} (grep {$_->[0] == $inode->parent()->ord()} (@{$inode->wild()->{enhanced}}));
            $edeprel = $edeprels[0] if(scalar(@edeprels) > 0);
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



###!!! This should later go to its own block.
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
    if($node->is_shared_modifier() && $node->deprel() !~ m/^(conj|cc|punct)(:|$)/)
    {
        # Presumably the parent node is a head of coordination but better check it.
        if(defined($node->parent()))
        {
            my @conjuncts = $self->recursively_collect_conjuncts($node->parent());
            foreach my $conjunct (@conjuncts)
            {
                # Although we mostly look at the basic tree for input, we must copy
                # the deprel from the enhanced graph because it may have been enhanced
                # with case information.
                my $edeprel = $node->deprel();
                my @edeprels = map {$_->[1]} (grep {$_->[0] == $node->parent()->ord()} (@{$node->wild()->{enhanced}}));
                $edeprel = $edeprels[0] if(scalar(@edeprels) > 0);
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
    my @conjuncts = grep {$_->deprel() =~ m/^conj(:|$)/} ($node->children());
    my @conjuncts2;
    foreach my $c (@conjuncts)
    {
        my @c2 = $self->recursively_collect_conjuncts($c);
        if(scalar(@c2) > 0)
        {
            push(@conjuncts2, @c2);
        }
    }
    return (@conjuncts, @conjuncts2);
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
    my $reldeprel = $relativizer->deprel();
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
#        my @relenhanced = grep {$_->[0] != $relparent->ord()} (@{$relativizer->wild()->{enhanced}});
#        $relativizer->wild()->{enhanced} = \@relenhanced;
        # Even if the relativizer is adverb or determiner, the new dependent will be noun or pronoun.
        $reldeprel =~ s/^advmod(:|$)/obl$1/;
        $reldeprel =~ s/^det(:|$)/nmod$1/;
        push(@{$noun->wild()->{enhanced}}, [$relparent->ord(), $reldeprel]);
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CopyBasicToEnhancedUD

=head1 DESCRIPTION

In Universal Dependencies, there is basic and enhanced representation. The
basic representation is a tree and corresponds to the a-tree in Treex. The
enhanced representation is a directed graph and can be optionally stored in
wild attributes of individual nodes (there is currently no API for the
enhanced structure).

The enhanced graph is independent of the basic tree. It is not guaranteed that
all tree edges also exist in the enhanced graph. Therefore, if we want to work
with enhanced dependencies, we probably want to copy the tree to the parallel
enhanced structure first. That is what this block does.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018, 2019 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

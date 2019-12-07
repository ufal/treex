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
            push(@{$node->wild()->{enhanced}}, [$inode->parent()->ord(), $inode->deprel()]);
            # The coordination may function as a shared dependent of other coordination.
            # In that case, make me depend on every conjunct in the parent coordination.
            if($inode->is_shared_modifier())
            {
                my @conjuncts = $self->recursively_collect_conjuncts($inode->parent());
                foreach my $conjunct (@conjuncts)
                {
                    push(@{$node->wild()->{enhanced}}, [$conjunct->ord(), $inode->deprel()]);
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
                push(@{$node->wild()->{enhanced}}, [$conjunct->ord(), $node->deprel()]);
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
    my $deprel = $node->deprel();
    # The guidelines allow enhancing nmod, acl, obl and advcl.
    # If it makes sense in the language, core relations obj, iobj and ccomp can be enhanced too.
    # Sebastian's enhancer further enhances conj relations with the lemma of the conjunction, but it is not supported in the guidelines.
    return unless($deprel =~ m/^(nmod|acl|obl|advcl)(:|$)/);
    # Collect case and mark children.
    my @casemark = grep {$_->deprel() =~ m/^(case|mark)(:|$)/} ($node->children({'ordered' => 1}));
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
    $cmlemmas = undef if($l eq '');
    if(defined($cmlemmas))
    {
        $deprel .= ":$cmlemmas";
    }
    # Look for morphological case only if this is a nominal and not a clause.
    if($deprel =~ m/^(nmod|obl)(:|$)/)
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
            $deprel .= ':'.lc($case);
        }
    }
    $node->set_deprel($deprel);
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

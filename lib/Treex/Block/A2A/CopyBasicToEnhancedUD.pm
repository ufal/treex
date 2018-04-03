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
        # Find the nearest non-conj ancestor.
        my $inode = $node->parent();
        while(defined($inode))
        {
            last if($inode->deprel() !~ m/^conj(:|$)/);
            $inode = $inode->parent();
        }
        if(defined($inode) && defined($inode->parent()))
        {
            push(@{$node->wild()->{enhanced}}, [$inode->parent()->ord(), $inode->deprel()]);
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
    if($node->is_shared_modifier())
    {
        ###!!! I do not know whether all conjuncts in a coordinate shared dependent have the flag set!
        if($node->deprel() =~ m/^conj(:|$)/)
        {
            log_warn('Shared dependent is also conjunct');
            return;
        }
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

Copyright © 2018 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::A2A::ConvertTags;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $wild = $node->wild();
    # $wild->{enhanced} is a list of pairs, where each pari contains:
    # - a reference to a parent node
    # - the type of the relation between the parent node and this node
    my $parent = $node->parent();
    my $deprel = $node->deprel();
    my @deps = ();
    push(@deps, [$parent, $deprel]);
    # We assume that $wild->{enhanced} does not exist yet. If it does, we overwrite it!
    $wild->{enhanced} = \@deps;
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

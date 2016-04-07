package Treex::Block::Align::MarkConsistentTreelets;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has layer => ( is => 'ro', isa => 'Treex::Type::Layer', default => 't' );

my %al_subtree;
my $tree2;

sub process_zone {
    my ( $self, $zone1 ) = @_;
    %al_subtree = ();
    my $tree1 = $zone1->get_tree($self->layer);
    $tree2 = undef;
    $self->process_node($tree1, 1);
    $self->process_node($tree2, 0) if $tree2;
    return;
}

sub process_node {
    my ( $self, $node1, $is_src ) = @_;

    # Find $node2 which is aligned to $node1
    my $node2;
    if ($is_src){
        ($node2) = $node1->get_aligned_nodes_of_type('int|rule-based');
        $tree2 ||= $node2->get_root() if $node2;
    } else {
        ($node2) = grep {$_->is_directed_aligned_to($node1, {rel_types => ['int|rule-based']}) } $node1->get_referencing_nodes('alignment');
    }

    # If $node1 is aligned, save its alignment as a string to @my_al.
    my @my_al = ();
    if ($node2) {
        @my_al = $is_src ? ($node1->ord . '-' . $node2->ord) : ($node2->ord . '-' . $node1->ord);
    }

    # Recursively, gather alignments of all descendants of $node1.
    my @alignments = sort (@my_al, map {$self->process_node($_, $is_src)} $node1->get_children());
    
    # If $node1 is aligned (or it is the effective root of the tree, i.e. the main verb),
    # save a mapping in the "src" phase, or retrieve it in the "trg" phase
    if ($node2 || !$node1->is_root && $node1->get_parent->is_root) {
        my $al_key = join ',', @alignments;
        if ($is_src){
            $al_subtree{$al_key} = $node1;
        } else {
            my $root2 = $al_subtree{$al_key};
            if ($root2){
                $root2->wild->{ali_root} = $node1->id;
                $node1->wild->{ali_root} = $root2->id;
            }
        }
    }
    
    return @alignments;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Align::MarkConsistentTreelets - mark roots of treelets consistent with alignment

=head1 DESCRIPTION

The implementation is based on algorithm described in
Yvette Graham, Josef van Genabith: An Open Source Rule Induction Tool for Transfer-Based SMT. PBML91, 2009.
http://ufal.mff.cuni.cz/pbml/91/art-graham.pdf

=head1 PARAMETERS

=head3 C<layer>

The layer of the aligned trees (default: t).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

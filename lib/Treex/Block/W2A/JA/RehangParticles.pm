package Treex::Block::W2A::JA::RehangParticles;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

# While recursively depth-first-traversing the tree
# we sometimes rehang already processed parent node as a child node.
# But we don't want to process such nodes again.
my %is_processed;

sub process_atree {
    my ( $self, $a_root ) = @_;
    %is_processed = ();
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;

    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }
    $is_processed{$a_node} = 1;

    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }

    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    return 0 if $tag !~ /^Joshi/;

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # case particles should not depend on the preceeding nodes (Kakujoshi)
    # same probably applies for conjunction articles SetsuzokuJoshi
    return 0 if ( ($tag !~ /Kakujoshi/ && $tag !~ /SetsuzokuJoshi/ ) || $parent->ord > $a_node->ord);

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();
    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    return;
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::RehangParticles - Modifies position of the remaining particles within an a-tree. 

=head1 DESCRIPTION

Modifies the topology of trees parsed by JDEPP parser.

Modifies the position of some case particles if they are depending on a preceeding node.

Since this block finishes the after-parsing modifications of the a-tree, it should be aplied last.

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

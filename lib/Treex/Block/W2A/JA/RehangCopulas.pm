package Treex::Block::W2A::JA::RehangCopulas;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;

extends 'Treex::Core::Block';

# We rehang copula (lemmas "だ" and "です"), which are marked as auxiliary verbs but are often dependent on non-verb token (noun, adjective...). In this case they function as a predicate in a sentence (often translated as "to be"), so we want to change the dependecy.

# TODO: take care of "では" stem form of a copula

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
    my $lemma = $a_node->lemma;

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
    my $lemma = $a_node->lemma;
    return 0 if $tag !~ /^Jodōshi/;
    
    return 0 if ( $lemma ne "です" && $lemma ne "だ" && $lemma ) ;

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # we only switch copula, if their parent is a non-verb (otherwise they really are just auxiliary verbs, e.g formal past negation ありません "でし"  た).
    return 0 if $parent->tag() =~ /^Dōshi/;

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();
    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    foreach my $child ( $parent->get_children() ) {
      $child->set_parent($a_node);
    }
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::RehangCopulas - Modifies location of the Japanese copula within an a-tree.

=head1 DESCRIPTION

Modifies the topology of trees parsed by JDEPP parser.
The word made into predicate by copula should depend on the copula,
because we hope that way the sentence should be easier to translate.

---

Suggested order of applying Rehang* blocks:
W2A::JA::RehangAuxVerbs
W2A::JA::RehangCopulas
W2A::JA::RehangConjunctions
W2A::JA::RehangParticles

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

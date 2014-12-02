package Treex::Block::W2A::JA::RehangNouns;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;

extends 'Treex::Core::Block';

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
    return 0 if ($tag !~ /^Meishi/);

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # given the head-final nature of the Japanese language verbs preceeding the noun (in the sense of the word order) should be dependent on the noun and not vice versa, because they are most likely its modifiers
    return 0 if ($parent->tag !~ /^Dōshi/ || $parent->ord > $a_node->ord);

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

Treex::Block::W2A::JA::RehangAuxVerbs - Modifies the position of nouns and their verb modifiers within an a-tree.
E.g. "調べた" "ホテル"

=head1 DESCRIPTION

Verbs (Dōshi) which are preceeding a noun should never be its parent. This error is caused by wrong bunsetsu "clustering" during parsing phase.
This block takes care of that.

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

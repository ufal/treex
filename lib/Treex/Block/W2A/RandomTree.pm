package Treex::Block::W2A::RandomTree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_atree {
    my ( $self, $aroot ) = @_;

    my @anodes = $aroot->get_descendants();


    # first, flatten the tree structure, so that the now random structure doesn't depend on the previous one
    foreach my $anode (@anodes) {
        $anode->set_parent($aroot);
    }

    # make random permutation of all nodes and rehang them
    my @random_numbers = map {rand()} @anodes;
    foreach my $anode (map {$anodes[$_]} sort {$random_numbers[$a] <=> $random_numbers[$b]} (0 .. $#random_numbers)) {
        my %is_in_subtree;
        map {$is_in_subtree{$_} = 1} ($anode, $anode->get_descendants);
        my @possible_parents = grep {!$is_in_subtree{$_}} (@anodes, $aroot);
        $anode->set_parent($possible_parents[int(rand(@possible_parents))]);
    }
}

1;

__END__
 
=head1 NAME

Treex::Block::W2A::RandomTree

=head1 DECRIPTION

This block rehangs a given tree randomly.
Node attributes are not changed.

=head1 COPYRIGHT

Copyright 2011 David Mareček
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

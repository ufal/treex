package Treex::Block::A2T::FixAtomicNodes;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    return if ( $tnode->nodetype ne 'atom' );

    my @children = $tnode->get_children();

    #  rehang all the children and the atomic node itself under the first child
    if ( @children > 1 ) {

        my $firstchild = shift @children;

        $firstchild->set_is_member( $tnode->is_member );
        $tnode->set_is_member(undef);
        $firstchild->set_parent( $tnode->get_parent );
        $tnode->set_parent($firstchild);

        foreach my $child (@children) {
            $child->set_parent($firstchild);
        }
    }

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::FixAtomicNodes

=head1 DESCRIPTION

Ensures that no atomic node (nodetype=atom) has more than one child (which is possible in phrases such as "na druhou stranu",
"v každém případě", "s největší pravděpodobností" etc.).

=head1 TODO

Rehanging all the children under the first child of the atomic node is rather dumb, some hierarchy based on 
functors and word order should probably be applied, such as in C<Treex::Block::T2A::DeleteGeneratedNodes>.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

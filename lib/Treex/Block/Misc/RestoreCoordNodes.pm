package Treex::Block::Misc::RestoreCoordNodes;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # TODO add more conjunctions, but now it's ok for me
    return if ( $tnode->formeme ne 'x' or $tnode->t_lemma !~ /^(and|or|but|yet)$/ );
    $tnode->set_functor('CONJ'); # needed for is_coap_root

    # first, check for adjacent children of the same formeme and only fix is_member
    my @children = $tnode->get_children( { ordered => 1 } );
    my $found = 0;

    for ( my $i = 0; $i < @children - 1; ++$i ) {
        if ( $children[$i]->formeme eq $children[ $i + 1 ]->formeme ) {
            $children[$i]->set_is_member(1);
            $children[ $i + 1 ]->set_is_member(1);
            $found = 1;
            log_info( 'Match (1)' . $tnode->id );
        }
    }
    return if ($found);

    # second, check if we don't sit between brother nodes
    # TODO fix also more conjuncts, this only works for two
    my ($left)  = $tnode->get_left_neighbor();
    my ($right) = $tnode->get_right_neighbor();

    if ( $left and $right and ( $left->formeme eq $right->formeme ) ) {
        $left->set_parent($tnode);
        $right->set_parent($tnode);
        $left->set_is_member(1);
        $right->set_is_member(1);
        log_info( 'Match (2)' . $tnode->id );
        return;
    }

    # third, check for Stanford-style (try right neighbor and parent)
    # TODO fix also more conjuncts, this only works for two
    my ($parent) = $tnode->get_parent();
    if ( $right and ( ( $parent->formeme // '' ) eq $right->formeme ) ) {
        $tnode->set_parent( $parent->get_parent() );
        $parent->set_parent($tnode);
        $right->set_parent($tnode);
        $parent->set_is_member(1);
        $right->set_is_member(1);
        log_info( 'Match (3)' . $tnode->id );
    }

    return;
}

1;


__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Misc::RestoreCoordNodes

=head1 DESCRIPTION

Restoring coordination nodes for the Tgen generator (either fixing is_member, or rehanging
after C<Misc::DeleteCoordNodes>).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2A::DropPersPronSbImper;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my @parents = $t_node->get_eparents({or_topological => 1});
    if ($t_node->t_lemma eq '#PersPron'
        && $t_node->formeme eq 'n:subj'
        && @parents
        && grep { ($_->sentmod // '') eq 'imper' } @parents
    ){
        my $a_node = $t_node->get_lex_anode();
        $self->drop($a_node);
    }
    return;
}

sub drop {
    my ($self, $a_node) = @_;
    return if !$a_node;

    # rehang PersPron's children (theoretically there should be none, but ...)
    foreach my $a_child ( $a_node->get_children() ) {
        $a_child->set_parent( $a_node->get_parent() );
    }

    # delete the a-node
    $a_node->remove();
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::DropPersPronSbImper - delete subjects of imperatives

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

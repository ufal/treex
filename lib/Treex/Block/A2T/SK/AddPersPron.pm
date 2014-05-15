package Treex::Block::A2T::SK::AddPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::CS::AddPersPron';

sub _get_anode_tags {
    my ($self, $t_node) = @_;
    return map { $_->wild->{tag_cs_pdt} } ( $t_node->get_lex_anode, $t_node->get_aux_anodes );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SK::AddPersPron

=head1 DESCRIPTION

New Slovak nodes with t_lemma #PersPron corresponding to unexpressed ('prodropped') 
subjects of finite clauses are added.

This is just a thin wrapper over the Czech block, L<Treex::Block::A2T::CS::AddPersPron>.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

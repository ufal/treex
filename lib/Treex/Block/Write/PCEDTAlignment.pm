package Treex::Block::Write::PCEDTAlignment;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.align' );

sub process_tnode {
    my ( $self,     $tnode ) = @_;
    my ( $cs_nodes, $types ) = $tnode->get_directed_aligned_nodes();
    return if !$$cs_nodes[0];
    my $cs_tnode = $$cs_nodes[0];
    return if !$tnode->get_lex_anode;
    my $p_node = $tnode->get_lex_anode->get_terminal_pnode;
    if ( $p_node->id =~ /EnglishP-(wsj_.+\d)$/ ) {
        print { $self->_file_handle } join( "\t", ( $1, $p_node->form, $p_node->tag, $cs_tnode->id, $cs_tnode->t_lemma, $cs_tnode->functor ) ) . "\n";
    }
}

1;

__END__

=head1 NAME

Treex::Block::Write::PCEDTAlignment

=head1 AUTHOR

David Mareček

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

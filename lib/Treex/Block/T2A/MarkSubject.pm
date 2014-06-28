package Treex::Block::T2A::MarkSubject;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    if ($t_node->formeme eq 'n:subj'){
        my $a_node = $t_node->get_lex_anode() or return;
        $a_node->set_afun('Sb');
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::MarkSubject

=head1 DESCRIPTION

Fill afun=Sb for anodes which correspond to t-nodes with formeme "n:subj".

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

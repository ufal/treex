package Treex::Block::T2A::PT::MarkSubject;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::MarkSubject';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    if ($t_node->formeme eq 'n:subj' || $t_node->formeme eq 'n:poss'){
        my $a_node = $t_node->get_lex_anode() or return;
        $a_node->set_afun('Sb');
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::MarkSubject

=head1 DESCRIPTION

Mark subject

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



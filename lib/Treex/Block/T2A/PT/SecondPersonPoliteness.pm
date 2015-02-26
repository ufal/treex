package Treex::Block::T2A::PT::SecondPersonPoliteness;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ($t_node->t_lemma eq "#PersPron" and $t_node->gram_person eq "2") {
        my $a_node = $t_node->get_lex_anode() or return;
        $a_node->iset->set_person(3);
       
    }

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::SecondPersonPoliteness

=head1 DESCRIPTION

Sets politeness for portuguese (third person) 

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.




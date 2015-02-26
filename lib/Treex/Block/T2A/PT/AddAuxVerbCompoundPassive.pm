package Treex::Block::T2A::PT::AddAuxVerbCompoundPassive;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    return if ( $t_node->voice || $t_node->gram_diathesis || '' ) !~ /^pas/;
    my $a_node = $t_node->get_lex_anode() or return;

    my $gender = $a_node->get_attr('iset/gender') // '';
    my $number = $a_node->get_attr('iset/number') // '';

    my $new_node = $a_node->create_child({
            'lemma'         => 'ser',
            'afun'          => 'AuxV',
        });

    $new_node->iset->set_gender($gender);
    $new_node->iset->set_number($number);
    $new_node->iset->set_pos('verb');
    $new_node->iset->set_person('3');
    $new_node->iset->set_mood('ind');
    $new_node->iset->set_tense('pres');

    $new_node->shift_before_node($a_node);
    $t_node->add_aux_anodes($new_node);


    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::AddAuxVerbCompoundPassive

=head1 DESCRIPTION

Added portuguese auxiliary verb 'ser' to a passive verb

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


package Treex::Block::A2T::LA::FixTlemmas;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $lex_anode = $t_node->get_lex_anode;
    my $lex_lemma = $lex_anode->lemma;

    # the #PersPron t-lemma is assigned to all the n.pron.def.pers. (personal-possessive-reflexive pronouns)
    # NB! This is not a grammateme, but an attribute
        if (grep $lex_lemma eq $_, qw(ego tu meus tuus suus vester noster sui)) {
            $t_node->set_attr('t_lemma', '#PersPron');
    }

    # the #Neg t-lemma is assigned to 'non'
    # NB! This is not a grammateme, but an attribute
        if ($lex_lemma eq 'non') {
            $t_node->set_attr('t_lemma', '#Neg');
    }

    # the t-lemma 'qui' is assigned to nodes with m-lemma "aliqui/quicumque/quidam/quilibet"
    # NB! This is not a grammateme, but an attribute
        if (grep $lex_lemma eq $_, qw(aliqui quicumque quidam quilibet)) {
            $t_node->set_attr('t_lemma', 'qui');
    }

    # the t-lemma 'quis' is assigned to nodes with m-lemma "aliquis/quisquis/unusquisque"
    # NB! This is not a grammateme, but an attribute
        if (grep $lex_lemma eq $_, qw(aliquis quisquis unusquisque)) {
            $t_node->set_attr('t_lemma', 'quis');
    }

    # the t-lemma 'qualis' is assigned to nodes with m-lemma 'qualiscumque'
    # NB! This is not a grammateme, but an attribute
        if ($lex_lemma eq 'qualiscumque') {
            $t_node->set_attr('t_lemma', 'qualis');
    }

    # the t-lemma 'quantus' is assigned to nodes with m-lemma 'quantuscumque'
    # NB! This is not a grammateme, but an attribute
        if ($lex_lemma eq 'quantuscumque') {
            $t_node->set_attr('t_lemma', 'quantus');
    }

    # the t-lemma 'ipse' is assigned to nodes with m-lemma 'seipse'
    # NB! This is not a grammateme, but an attribute
        if ($lex_lemma eq 'seipse') {
            $t_node->set_attr('t_lemma', 'ipse');
    }

    # the t-lemma 'uter' is assigned to nodes with m-lemma 'uterque'
    # NB! This is not a grammateme, but an attribute
        if ($lex_lemma eq 'uterque') {
            $t_node->set_attr('t_lemma', 'uter');
    }


    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::FixTlemmas - fill t-lemmas

=head1 DESCRIPTION

hand-written rules

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

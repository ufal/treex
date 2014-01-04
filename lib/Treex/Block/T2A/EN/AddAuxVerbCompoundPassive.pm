package Treex::Block::T2A::EN::AddAuxVerbCompoundPassive;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;

    return if ( $t_node->voice || $t_node->gram_diathesis || '' ) !~ /^pas/;
    my $a_node = $t_node->get_lex_anode() or return;

    # we will move the autosemantic node as in Czech synthesis (see also corresponding block in Czech)
    my $new_node = $a_node->create_child();
    $new_node->shift_after_node($a_node);

    # the new node will carry the autosemantic verb
    $new_node->reset_morphcat();
    $new_node->set_lemma( $a_node->lemma );
    $new_node->set_form( $a_node->form );
    $new_node->set_morphcat_pos( 'V' );
    $new_node->set_morphcat_negation( 'A' );
    $new_node->set_morphcat_voice( 'P' );
    $new_node->set_morphcat_tense( 'R' );
    $new_node->set_conll_pos( 'VBN' );

    # $a_node is now auxiliary "být" and governs the autosemantic verb
    $a_node->set_lemma('be');
    $a_node->set_morphcat_voice( 'A' );
    $a_node->set_afun('AuxV');

    # Add a link (aux.rf) from the t-layer node to $new_node (even though it carries the autosemantic verb,
    # it will be 'auxiliary' for the purposes of further synthesis).
    $t_node->add_aux_anodes($new_node);

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddAuxVerbCompoundPassive

=head1 DESCRIPTION

Add auxiliary 'to be' a-node in the case of compound passive verb forms.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

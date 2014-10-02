package Treex::Block::T2A::NL::AddAuxVerbCompoundPassive;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    return if ( $tnode->voice || $tnode->gram_diathesis || '' ) !~ /^pas/;
    my $anode = $tnode->get_lex_anode() or return;

    # we will move the autosemantic node, same as in Czech synthesis
    my $new_node = $anode->create_child({
        'lemma' => $anode->lemma,
        'form' => $anode->form,
        'iset' => $anode->iset,
        'afun' => 'Obj',
    });
    $new_node->shift_after_node($anode);

    # $anode is now auxiliary "worden" or "zijn" and governs the autosemantic verb
    my $aux_lemma = 'worden';
    if ($anode->match_iset('tense' => '^(past|pqp)$')){
        $aux_lemma = 'zijn';
    }
    $anode->set_lemma($aux_lemma);
    $anode->set_afun('AuxV');

    # Add a link (aux.rf) from the t-layer node to $new_node (even though it carries the autosemantic verb,
    # it will be 'auxiliary' for the purposes of further synthesis).
    $tnode->add_aux_anodes($new_node);

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::AddAuxVerbCompoundPassive

=head1 DESCRIPTION

Add auxiliary 'worden'/'zijn' a-node in the case of compound passive verb forms.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2A::EN::AddAuxVerbInter;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # select only interogative verbs
    return if (
        ($t_node->formeme // '') !~ /^v.*fin/
        || ($t_node->sentmod // '') ne 'inter'
        || $t_node->t_lemma eq 'there'
    );
    
    my $a_node = $t_node->get_lex_anode() or return;

    # if the current main verbal node is not auxiliary (or not `be'), shift it and put an auxiliary 'do' in its place
    return if ( ( $a_node->afun // '' ) eq 'AuxV' or $a_node->lemma eq 'be' );

    # this is where the main verb will go (in infinitive)
    my $new_node = $a_node->create_child(
        {
            'lemma'           => $a_node->lemma,
            'form'            => $a_node->form,
            'afun'            => 'Obj',
            'morphcat/pos'    => 'V',
            'morphcat/subpos' => 'f',
            'conll/pos'       => 'VB',
        }
    );
    $new_node->shift_after_node($a_node);

    # $a_node is now the auxiliary "do" and governs the autosemantic verb
    my $lemma = $t_node->t_lemma eq '#PersPron' ? 'be' : 'do';
    $a_node->set_lemma($lemma);
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

Treex::Block::T2A::EN::AddAuxVerbInter

=head1 DESCRIPTION

Add the auxiliary 'do' for interrogative verbs.

=head1 AUTHORS 

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

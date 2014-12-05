package Treex::Block::T2A::EN::AddVerbNegation;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # select only negated verbs
    return if ( ( $t_node->gram_sempos || '' ) !~ /^v/ or ( $t_node->gram_negation || '' ) ne 'neg1' );
    my $a_node = $t_node->get_lex_anode() or return;

    # create the particle 'not'
    my $neg_node = $a_node->create_child(
        {
            'lemma'        => 'not',
            'form'         => 'not',
            'afun'         => 'Neg',
            'morphcat/pos' => '!',
        }
    );
    $neg_node->shift_after_node($a_node);
    $t_node->add_aux_anodes($neg_node);

    # if the current main verbal node is not auxiliary (or not `be'), shift it and put an auxiliary 'do' in its place
    return if ( ( $a_node->afun || '' ) eq 'AuxV' or $a_node->lemma eq 'be' );

    # this is where the main verb wil go (in infinitive)
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
    $new_node->shift_after_node($neg_node);

    # $a_node is now the auxiliary "do" and governs the autosemantic verb
    $a_node->set_lemma('do');
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

Treex::Block::T2A::EN::AddVerbNegation

=head1 DESCRIPTION

Add the particle 'not' and the auxiliary 'do' for negated verbs.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

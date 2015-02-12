package Treex::Block::T2A::EN::AddAuxVerbThereIs;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # select only 'there' marked as a verb
    return if (
        ($t_node->formeme // '') !~ /^v.*fin/
        || $t_node->t_lemma ne 'there'
    );
    
    my $a_node = $t_node->get_lex_anode() or return;

    # this is where the main verb will go
    my $new_node = $a_node->create_child(
        {
            'lemma'           => $a_node->lemma,
            'form'            => $a_node->form,
            'afun'            => 'Sb', 
            'morphcat/pos'    => 'D',
            'conll/pos'       => 'EX',
        }
    );
        
    if (($t_node->sentmod // '') eq 'inter') {
        # is there
        $new_node->shift_after_node($a_node);
    } else {
        # there is
        $new_node->shift_before_node($a_node);
    }
    
    # $a_node is now the auxiliary "be" and governs the autosemantic verb
    $a_node->set_lemma('be');
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

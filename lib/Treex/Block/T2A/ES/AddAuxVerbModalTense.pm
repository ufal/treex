package Treex::Block::T2A::ES::AddAuxVerbModalTense;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddAuxVerbModalTense';

override '_build_gram2form' => sub {

    return {
	''        => '',
	'decl'    => '',
	'poss'    => 'poder',
	'vol'     => 'querer',
	'deb'     => 'deber',
	'hrt'     => 'deber',
	'fac'     => 'poder',
	'perm'    => 'poder',
    };
};

override 'process_tnode' => sub {
    my ( $self, $tnode ) = @_;
    my ( $verbmod, $tense, $deontmod, $aspect ) = ( $tnode->gram_verbmod // '', $tnode->gram_tense // '', $tnode->gram_deontmod // '', $tnode->gram_aspect // '');

    # return if the node is not a verb
    return if ( !$verbmod );

    # find the auxiliary appropriate verbal expression for each deontic modality
    # do nothing if we find nothing
    # TODO this should handle epistemic modality somehow. The expressions are in the array, but are ignored.
    return if ( !$self->gram2form->{$deontmod} );
    my $verbforms_str = $self->gram2form->{$deontmod};
    return if ( !$verbforms_str );

    # find the original anode
    my $anode = $tnode->get_lex_anode() or return;
    my $lex_lemma = $anode->lemma;

    my ( $first_verbform, @verbforms ) = split / /, $verbforms_str;

    # replace the current verb node by the first part of the auxiliary verbal expression
    $anode->set_lemma($first_verbform);
    $anode->set_afun('AuxV');

    my $created_lex = 0;
    my @anodes      = ();

    # add the rest (including the original verb) as "auxiliary" nodes
    foreach my $verbform ( $lex_lemma, reverse @verbforms ) {

        my $new_node = $anode->create_child();
        $new_node->shift_after_node($anode);
        $new_node->reset_morphcat();

        $new_node->set_lemma($verbform);
        $tnode->add_aux_anodes($new_node);
        unshift @anodes, $new_node;

        # creating auxiliary part
        if ($created_lex) {
            $new_node->set_morphcat_pos('!');
            $new_node->set_form($verbform);
            $new_node->set_afun('AuxV');
        }

        # creating a new node for the lexical verb
        else {
            $new_node->set_morphcat_pos('!');
            $new_node->set_afun('AuxV');
	    $new_node->set_form($verbform);
	    $new_node->iset->add( 'pos' => 'verb', 'verbform' => 'inf');
            # mark the lexical verb for future reference (if not already marked by AddAuxVerbCompoundPassive)
            if ( !grep { $_->wild->{lex_verb} } $tnode->get_aux_anodes() ) {
                $new_node->wild->{lex_verb} = 1;
            }
            $created_lex = 1;
        }
    }

    $self->_postprocess( $verbforms_str, \@anodes );

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddAuxVerbModalTense

=head1 DESCRIPTION

Add auxiliary expression for combined modality and tense.

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::T2A::NL::FixAuxVerbsAlpinoStyle;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # return if we don't have any auxiliary verbs
    return if ( $tnode->formeme !~ /^v/ or !grep { $_->afun =~ /^(AuxV|Obj)$/ } $tnode->get_aux_anodes() );

    # get the lexical verb (it's now set as one of the auxiliaries)
    my $amain_verb = first { $_->wild->{lex_verb} } $tnode->get_aux_anodes();
    if ( !$amain_verb ) {
        my $lemma = $tnode->t_lemma;
        $amain_verb = first { $_->lemma eq $lemma } $tnode->get_aux_anodes();
        if ( !$amain_verb ) {
            $lemma =~ s/_//g;
            $amain_verb = first { $_->lemma eq $lemma } $tnode->get_aux_anodes();
        }
        if ( !$amain_verb ) {
            $lemma =~ s/_.*//;
            $amain_verb = first { $_->lemma eq $lemma } $tnode->get_aux_anodes();
        }
    }
    return if ( !$amain_verb );    # no lexical verb found (happens mainly with infinitives)

    # get the main auxiliary verb that keeps all the children
    my $aaux_verb = $tnode->get_lex_anode() or return;

    # move the children to the main lexical verb (except for the subject, where a coindex node is created)
    my $asubj = undef;
    my $acoindex = undef;
    my %aaux = map { $_->id => 1 } $tnode->get_aux_anodes();

    foreach my $achild ( $aaux_verb->get_children() ) {

        # subject: create coindexing formal subject
        if ( ( $achild->afun // '' ) eq 'Sb' ) {
            next if ($asubj);    # do this only once

            my $afun = ( ( $tnode->gram_diathesis // '' ) eq 'pas' ? 'Obj' : 'Sb' );
            $asubj = $achild;
            $acoindex = $self->_add_coindex_node( $amain_verb, $asubj, $afun );
        }

        # move children (other than own Aux's)
        elsif ( !$aaux{ $achild->id } ) {
            $achild->set_parent($amain_verb);
        }
    }
    return if (!$asubj);
    
    # shift the coindex node to the beginning of the main verb's subtree
    # (we can do this only now since the subtree has just been moved from the 1st auxiliary)
    $acoindex->shift_before_subtree($amain_verb);

    # hierarchical ordering & coindexing nodes for the "middle part" of the verbal complex
    # (i.e. everything between the lexical verb and the 1st auxiliary)
    my $aprev_top = $amain_verb;
    foreach my $aaux_hier ( reverse grep { $_->afun =~ /^(AuxV|Obj)$/ && $_ != $amain_verb } $tnode->get_aux_anodes( { ordered => 1 } ) ) {
        $aaux_hier->set_parent( $aprev_top->get_parent() );
        $aprev_top->set_parent($aaux_hier);
      
        my $acoindex = $self->_add_coindex_node( $aaux_hier, $asubj, 'Sb' );
        $acoindex->shift_before_subtree($aaux_hier);
      
        $aprev_top = $aaux_hier;
    }

    return;
}

sub _add_coindex_node {
    my ( $self, $averb, $asubj, $afun ) = @_;

    my $acoindex = $averb->create_child(
        {   'lemma'         => '',
            'form'          => '',
            'afun'          => $afun,
            'clause_number' => $averb->clause_number
        }
    );
    $acoindex->wild->{coindex} = $asubj->id;

    # coindex with the subject leaf node or its "whole phrase" node
    if ( !$asubj->is_leaf ) {
        $asubj->wild->{coindex_phrase} = $asubj->id;
    }
    else {
        $asubj->wild->{coindex} = $asubj->id;
    }
    return $acoindex;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::FixAuxVerbsAlpinoStyle

=head1 DESCRIPTION

Rehanging most children to the lexical (main) verb; adding a formal subject/object with the
lexical verb (empty form & lemma, wild/coindex.rf pointing to the true subject of an auxiliary verb).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

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
    my $acoindex;
    my %aaux = map { $_->id => 1 } $tnode->get_aux_anodes();

    foreach my $achild ( $aaux_verb->get_children() ) {
        if ( ( $achild->afun // '' ) eq 'Sb' ) {
            next if ($acoindex);
            $acoindex = $amain_verb->create_child(
                {   'lemma'         => '',
                    'form'          => '',
                    'afun'          => ( ( $tnode->gram_diathesis // '' ) eq 'pas' ? 'Obj' : 'Sb' ),
                    'clause_number' => $amain_verb->clause_number
                }
            );
            $acoindex->wild->{coindex} = $achild->id;
            $achild->wild->{coindex} = $achild->id;
        }
        elsif ( !$aaux{ $achild->id } ) {
            $achild->set_parent($amain_verb);
        }
    }

    # this is just to make it look better
    if ($acoindex) {
        $acoindex->shift_before_subtree($amain_verb);
    }

    return;
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

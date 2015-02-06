package Treex::Block::T2A::NL::Alpino::FixQuestionsAndRelClauses;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::NL::Pronouns;

extends 'Treex::Core::Block';

with 'Treex::Block::T2A::NL::Alpino::CoindexNodes';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    # TODO coordinated questions
    return if ( $tnode->formeme !~ /^v:(rc|indq)/ and ( $tnode->formeme ne 'v:fin' or ( $tnode->sentmod // '' ) ne 'inter' ) );

    # find the relative pronoun (or wh-) phrase
    my $anode = $tnode->get_lex_anode() or return;
    my $arpron_head;
    foreach my $achild ( $anode->get_children() ) {
        if ( any { Treex::Tool::Lexicon::NL::Pronouns::is_relative_pronoun( $_->lemma // '' ) and ( $_->afun // '') !~ /^Aux/ } $achild->get_descendants( { add_self => 1 } ) ) {
            $arpron_head = $achild;
            last;
        }
    }
    return if ( !$arpron_head );
    $arpron_head->shift_before_subtree($anode);
    
    # create a new "rhd" node (formal head of the relative clause), hang the relative pronoun and the rest of the clause under it as two siblings
    my $aparent = $anode->get_parent();
    my $arhd_formal = $aparent->create_child({ form => '', lemma => '', afun => 'Atr', clause_number => $arpron_head->clause_number });
    $arhd_formal->shift_before_subtree($arpron_head);
    $arpron_head->set_parent($arhd_formal);
    $anode->set_parent($arhd_formal);

    # distinguish questions and relative clauses & pre-assign appropriate ADT relation labels
    if ( $tnode->formeme =~ /^v:(indq|fin)/ ) {
        $arhd_formal->wild->{adt_phrase_rel} = $arhd_formal->get_parent->is_root ? '--' : 'vc';
        $arpron_head->wild->{adt_phrase_rel} = 'whd';
        $anode->wild->{adt_phrase_rel} = 'body';
    }
    else {
        $arhd_formal->wild->{adt_phrase_rel} = 'mod';
        $arpron_head->wild->{adt_phrase_rel} = 'rhd';
    }
    $arhd_formal->wild->{is_formal_head} = 1;  # mark the formal head so that it is skipped in ADTXML

	# set Afun (subject would have already been marked, so we can assume that it's an object in other cases)
    if (!$arpron_head->afun){
    	$arpron_head->set_afun( $arpron_head->lemma =~ /^(hoe|waneer|hoeveel)$/ ? 'Adv' : 'Obj' );
    }
    # create a coindexing node in the original place of the relative pronoun phrase
    my $acoindex = $self->add_coindex_node( $anode, $arpron_head, $arpron_head->afun );
    $acoindex->shift_before_subtree($anode);
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::FixQuestionsAndRelClauses

=head1 DESCRIPTION

Fixing questions and relative clauses for Alpino generator: adding formal "rhd"/"whd" nodes,
marking subject coindexing, pre-setting corresponding Alpino terminal and non-terminal relations.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

    

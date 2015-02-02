package Treex::Block::T2A::NL::Alpino::FixQuestionsAndRelClauses;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

with 'Treex::Block::T2A::NL::Alpino::CoindexNodes';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if ( $tnode->formeme ne 'v:rc' );

    # find the relative pronoun (or wh-) phrase
    my $anode = $tnode->get_lex_anode() or return;
    my $arpron_head;
    foreach my $achild ( $anode->get_children() ) {
        if ( any { ( $_->lemma // '' ) =~ /^(die|dat|wie|wiens|wat|welke?|wanneer|hoe|hetgeen)$/ and ( $_->afun // '') !~ /^Aux/ } $achild->get_descendants( { add_self => 1 } ) ) {
            $arpron_head = $achild;
            last;
        }
    }
    return if ( !$arpron_head );
    
    # create a new "rhd" node (formal head of the relative clause), hang the relative pronoun and the rest of the clause under it as two siblings
    my $aparent = $anode->get_parent();
    my $arhd_formal = $aparent->create_child({ form => '', lemma => '', afun => 'Atr', clause_number => $arpron_head->clause_number });
    $arhd_formal->shift_before_subtree($arpron_head);
    $arpron_head->set_parent($arhd_formal);
    $anode->set_parent($arhd_formal);

    # distinguish (indirect) questions and relative clauses: questions are below roots and verbs
    # & pre-assign appropriate ADT relation labels
    if ( $aparent->is_root || $aparent->is_verb ) {
        $arhd_formal->wild->{adt_phrase_rel} = 'vc';
        $arpron_head->wild->{adt_phrase_rel} = 'whd';
        $anode->wild->{adt_phrase_rel} = 'body';
        $anode->wild->{adt_term_rel} = 'body';
    }
    else {
        $arhd_formal->wild->{adt_phrase_rel} = 'mod';
        $arpron_head->wild->{adt_phrase_rel} = 'rhd';
    }
    $arhd_formal->wild->{is_formal_head} = 1;  # mark the formal head so that it is skipped in ADTXML

    # create a coindexing node in the original place of the relative pronoun phrase
    my $acoindex = $self->add_coindex_node( $anode, $arpron_head, ( $arpron_head->afun // 'Obj' ) );
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

    

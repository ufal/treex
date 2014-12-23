package Treex::Block::T2A::NL::FixQuestionsAlpinoStyle;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if ( $tnode->formeme ne 'v:rc' );

    # find the relative pronoun (or wh-) phrase
    my $anode = $tnode->get_lex_anode() or return;
    my $arpron_head;
    foreach my $achild ( $anode->get_children() ) {
        if ( any { ( $_->lemma // '' ) =~ /^(die|wie|wiens|wat|welke?|wanneer|hoe)$/ } $achild->get_descendants( { add_self => 1 } ) ) {
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
    if ( $aparent->is_root || $aparent->is_verb ) {
        $arhd_formal->wild->{is_whd_head} = 1;
    }
    else {
        $arhd_formal->wild->{is_rhd_head} = 1;
    }
    $anode->wild->{is_whd_body} = 1;

    # create a coindexing node in the original place of the relative pronoun phrase
    # if the relative pronoun is a longer phrase (has more nodes), coindex with the whole phrase
    my $acoindex = $anode->create_child( { form => '', lemma => '', afun => ( $arpron_head->afun // 'Obj' ) } );
    $acoindex->shift_before_subtree($anode);
    $acoindex->wild->{coindex} = $arpron_head->id;
    if ( $arpron_head->is_leaf ){
        $arpron_head->wild->{coindex} = $arpron_head->id;
    }
    else {
        $arpron_head->wild->{coindex_phrase} = $arpron_head->id;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::FixQuestionsAlpinoStyle

=head1 DESCRIPTION


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

    

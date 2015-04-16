package Treex::Block::T2A::EN::AddIntroPunct;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

with 'Treex::Block::T2A::EN::WordOrderTools';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    return if ( !$tnode->is_clause_head() );

    # avoid questions, avoid leaves, avoid punctuation, avoid single words, avoid wh-phrases
    my ($tfirst) = $tnode->get_echildren( { first_only => 1 } );
    return if ( !$tfirst or ( !$tfirst->get_children() and $tfirst->formeme !~ /\+/ ) );
    return if ( _is_wh_word( $tnode, $tfirst ) );

    # find the subject, proceed only if it is not the first child
    my ($tsubj) = first {
        my $a = $_->get_lex_anode();
        $a and ( $a->afun // '' ) eq 'Sb';
    }
    $tnode->get_echildren( { ordered => 1 } );

    return if ( !$tsubj or $tsubj == $tfirst );

    my $asubj = $tsubj->get_lex_anode();
    my $anode = $tnode->get_lex_anode();
    return if ( !$asubj or !$anode );

    # create a comma, hang it under the main verb
    my $acomma = $anode->create_child(
        {   'form'          => ',',
            'lemma'         => ',',
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );

    # place the comma before the subject subtree or before the main verb, what comes first
    if ( $asubj->precedes($anode) ) {
        $acomma->shift_before_subtree($asubj);
    }
    else {
        $acomma->shift_before_node($anode);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddIntroPunct

=head1 DESCRIPTION

Adding introductory punctuation that precedes the subject in the clause.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

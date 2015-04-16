package Treex::Block::T2A::EN::WordOrderTools;
use Moose::Role;
use Treex::Core::Common;

# grep a list of nodes for a given formeme regexp, abstract away from coordinations
sub _grep_formeme {
    my ( $formeme, $nodes_rf ) = @_;

    return grep {
        $_->formeme =~ /^$formeme$/
            or
            ( $_->is_coap_root and any { $_->formeme =~ /^$formeme$/ } $_->get_echildren( { or_topological => 1 } ) )
    } @$nodes_rf;
}

# Tests for a wh-word within the subtree of this child of a clause head (doesn't cross clause boundaries)
sub _is_wh_word {
    my ( $tverb, $tchild ) = @_;
    return 0 if ( $tchild->clause_number != $tverb->clause_number );
    my $wh_word = first { $_->t_lemma =~ /^(wh(at|ich|om?|ere|en|y)|how|that)$/ } ( $tchild, $tchild->get_clause_descendants() );
    return 0 if ( !$wh_word );

    # skip "that" without relative clause coreference
    return 0 if ( $wh_word->t_lemma eq 'that' and not $wh_word->get_coref_gram_nodes() );

    # skip "how" under infinitives ("how to do")
    if ( $wh_word->t_lemma eq 'how' ) {
        return 0 if ( grep { $_->formeme =~ /^v.*inf$/ } $wh_word->get_eparents( { or_topological => 1 } ) );
    }    
    return 1;
}

# find all wh-words among the children of the given verb
sub _find_wh_words {
    my ( $tverb, $tchildren_rf ) = @_;
    my @whs;

    foreach my $tchild (@$tchildren_rf) {
        if ( _is_wh_word( $tverb, $tchild ) ) {
            push @whs, $tchild;
        }
    }
    return @whs;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::WordOrderTools

=head1 DESCRIPTION

This is a Moose role containing helper functions for word-order-related blocks.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

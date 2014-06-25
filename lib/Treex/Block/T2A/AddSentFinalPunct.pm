package Treex::Block::T2A::AddSentFinalPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'open_punct' => ( is => 'ro', 'isa' => 'Str', default => '[‘“\']' );

has 'close_punct' => ( is => 'ro', 'isa' => 'Str', default => '[’”\']' );

sub process_zone {
    my ( $self, $zone ) = @_;
    my $troot = $zone->get_ttree();
    my $aroot = $zone->get_atree();

    my ($first_troot) = $troot->get_children();
    if ( !$first_troot ) {
        log_warn('No nodes in t-tree.');
        return;
    }

    # Don't put period after colon, semicolon, or three dots
    my $last_token = $troot->get_descendants( { last_only => 1 } );
    return if $last_token->t_lemma =~ /^[:;.]/;

    my $punct_mark = ( ( $first_troot->sentmod || '' ) eq 'inter' ) ? '?' : '.';
    
    my $punct = $aroot->create_child(
        {   'form'          => $punct_mark,
            'lemma'         => $punct_mark,
            'afun'          => 'AuxK',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
    $punct->iset->set_pos('punc');

    # The $punct goes to the end, except for some sentences with quotes:
    #   Do you know the word "pun"?
    #   "How are you?"
    if (  $self->_ends_with_clause_in_quotes($last_token) ) {
        $punct->shift_before_node( $last_token->get_lex_anode() );
    }
    else {
        $punct->shift_after_subtree($aroot);
    }

    $self->postprocess($punct);

    # TODO jednou by se mely pridat i koreny primych reci!!!
    return;
}

# To be implemented in language-specific child blocks
sub postprocess {
    return;
}

sub _ends_with_clause_in_quotes {

    my ( $self, $last_token ) = @_;
    my ( $open_punct, $close_punct ) = ( $self->open_punct, $self->close_punct );

    return 0 if $last_token->t_lemma !~ /$close_punct/;
    my @toks = $last_token->get_root->get_descendants( { ordered => 1 } );
    pop @toks;
    while (@toks) {
        my $tok = pop @toks;
        return 0 if $tok->t_lemma =~ /$open_punct/;
        return 1 if $tok->is_clause_head();
    }
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddSentFinalPunct

=head1 DESCRIPTION

Add a-nodes corresponding to sentence-final punctuation mark.

Note: final punctuation of direct speech is not handled yet!

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

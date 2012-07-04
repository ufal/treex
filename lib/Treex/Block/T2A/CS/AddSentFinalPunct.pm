package Treex::Block::T2A::CS::AddSentFinalPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

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

    #!!! dirty traversing of the pyramid at the lowest level
    # in order to distinguish full sentences from titles and imperatives
    # TODO: source language dependent code in synthesis!!!
    my $en_zone = $zone->get_bundle()->get_zone( 'en', 'src' );
    if ($en_zone && $en_zone->sentence){
        if ($en_zone->sentence =~ /!$/ ) {
            $punct_mark = '!';
        }
        return if $punct_mark eq '.' && $en_zone->sentence !~ /\./;
    }

    my $punct = $aroot->create_child(
        {   'form'          => $punct_mark,
            'lemma'         => $punct_mark,
            'afun'          => 'AuxK',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );

    # The $punct goes to the end, except for some sentences with quotes:
    #   Do you know the word "pun"?
    #   "How are you?"
    if (  _ends_with_clause_in_quotes($last_token) ) {
        $punct->shift_before_node( $last_token->get_lex_anode() );
    }
    else {
        $punct->shift_after_subtree($aroot);
    }

    # TODO jednou by se mely pridat i koreny primych reci!!!
    return;
}

sub _ends_with_clause_in_quotes {
    my ($last_token) = @_;
    return 0 if $last_token->t_lemma !~ /[“‘']/;
    my @toks = $last_token->get_root->get_descendants( { ordered => 1 } );
    pop @toks;
    while (@toks) {
        my $tok = pop @toks;
        return 0 if $tok->t_lemma =~ /[„‚']/;
        return 1 if $tok->is_clause_head();
    }
    return 0;
}

1;

__END__

# !!! pozor: koncovat interpunkce v primych recich neni zatim resena

=over

=item Treex::Block::T2A::CS::AddSentFinalPunct

Add a-nodes corresponding to sentence-final punctuation mark.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

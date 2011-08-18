package Treex::Block::A2T::CS::FixTlemmas;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

extends 'Treex::Core::Block';

sub possadj_to_noun {
    my $adj_mlemma = shift;

    $adj_mlemma =~ /\^(\([^\*][^\)]*\)_)?\(\*(\d+)(.+)?\)/;
    if ( !$2 ) {    # unfortunately, some lemmas do not contain the derivation information (TODO fix this somehow)
        log_warn( 'Cannot find base lemma for a possesive adjective: ' . $adj_mlemma );
        return $adj_mlemma;
    }
    my $cnt    = $2 ? $2 : 0;
    my $suffix = $3 ? $3 : "";    # no suffix if not defined (Nobelův -> Nobel)
    my $noun_mlemma = $adj_mlemma;
    $noun_mlemma =~ s/\_.+//;
    $noun_mlemma =~ s/.{$cnt}$/$suffix/;
    $noun_mlemma =~ s/\-.+//;
    return $noun_mlemma;
}

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $t_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $t_node->t_lemma, 1 );

    my $a_lex_node = $t_node->get_lex_anode();
    if ($a_lex_node) {
        if ( $a_lex_node->tag =~ /^P[PS5678H]/ ) {    # personal pronouns
            $t_lemma = "#PersPron";
        }
        elsif ( $a_lex_node->tag =~ /^AU/ ) {
            if ( $t_lemma =~ /^(.+)_/ ) {             # "von_Ryanuv", "de_Gaulluv"
                my $prefix = $1;
                $t_lemma = lc($prefix) . "_" . possadj_to_noun( $a_lex_node->lemma );
            }
            else {
                $t_lemma = possadj_to_noun( $a_lex_node->lemma );
            }
        }

    }

    my ($auxt) = grep { $_->afun eq "AuxT" } $t_node->get_aux_anodes;    # reflexiva tantum: smat_se
    if ( $auxt and not any { $_->lemma eq 'dát' } $t_node->get_aux_anodes ) {     # filter out modal 'dát se'
        $t_lemma .= "_" . lc( $auxt->form );                                      # preserve the "se/si" distinction
    }

    $t_node->set_t_lemma($t_lemma);

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::FixTlemmas

=head1 DESCRIPTION

Fixes t-lemmas for personal pronous, possesive adjectives and reflexiva tantum.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

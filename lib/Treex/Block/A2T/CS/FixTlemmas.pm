package Treex::Block::A2T::CS::FixTlemmas;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub possadj_to_noun {
    my $adj_mlemma = shift;

    $adj_mlemma =~ /\^\(\*(\d+)(.+)?\)/;
    my $cnt         = $1;
    my $suffix      = $2 ? $2 : "";    # no suffix if not defined (Nobelův -> Nobel)
    my $noun_mlemma = $adj_mlemma;
    $noun_mlemma =~ s/\_.+//;
    $noun_mlemma =~ s/.{$cnt}$/$suffix/;
    $noun_mlemma =~ s/\-.+//;
    return $noun_mlemma;
}

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $t_lemma = $t_node->t_lemma;
    $t_lemma =~ s /[\-\_\`](.+)$//;

    my $a_lex_node = $t_node->get_lex_anode();
    if ($a_lex_node) {
        if ( $a_lex_node->tag =~ /^P[PS5678H]/ ) {    # osobni zajmena
            $t_lemma = "#PersPron";
        }
        elsif ( $a_lex_node->tag =~ /^AU/ ) {
            if ( $t_lemma =~ /^(.+)_/ ) {             # von_Ryanuv, de_Gaulluv
                my $prefix = $1;
                $t_lemma = lc( $prefix . "_" . possadj_to_noun( $a_lex_node->lemma ) );
            }
            else {
                $t_lemma = lc( possadj_to_noun( $a_lex_node->lemma ) );
            }
        }

    }

    my ($auxt) = grep { $_->afun eq "AuxT" } $t_node->get_aux_anodes;    # reflexiva tantum: smat_se
    if ($auxt) {
        $t_lemma .= "_" . lc( $auxt->form );                             # zachovane rozliseni se/si
    }

    $t_node->set_t_lemma($t_lemma);

    return;
}

1;

=over

=item Treex::Block::A2T::CS::FixTlemmas

Fixes t-lemmas for personal pronous, possesive adjectives and reflexiva tantum.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

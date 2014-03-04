package Treex::Block::A2T::SK::FixTlemmas;
use Moose;
use Treex::Core::Common;
#use Treex::Tool::Lexicon::CS;

extends 'Treex::Core::Block';

# Can't do that in Slovak (yet)
#sub possadj_to_noun {
    #my $adj_mlemma = shift;

    #$adj_mlemma =~ /\^(\([^\*][^\)]*\)_)?\([^\*]*\*(\d+)(.+)?\)/;
    #if ( !$2 ) {    # unfortunately, some lemmas do not contain the derivation information (TODO fix this somehow)
        #log_warn( 'Cannot find base lemma for a possesive adjective: ' . $adj_mlemma );
        #return Treex::Tool::Lexicon::CS::truncate_lemma( $adj_mlemma, 1 );
    #}
    #my $cnt    = $2 ? $2 : 0;
    #my $suffix = $3 ? $3 : "";    # no suffix if not defined (Nobelův -> Nobel)
    #my $noun_mlemma = $adj_mlemma;
    #$noun_mlemma =~ s/\_.+//;
    #$noun_mlemma =~ s/.{$cnt}$/$suffix/;
    #$noun_mlemma =~ s/\-[0-9].*//;
    #return $noun_mlemma;
#}

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $t_lemma = $t_node->t_lemma;
    #my $t_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $t_node->t_lemma, 1 ); # no need in Slovak
    
    my $a_lex_node = $t_node->get_lex_anode();
    if ($a_lex_node) {
        if ( $a_lex_node->tag =~ /^P[PS5678H]/ ) {    # personal pronouns
            $t_lemma = "#PersPron";
        }
        elsif ( $a_lex_node->tag =~ /^AU/ ) {
            if ( $t_lemma =~ /^(.+)_/ ) {             # "von_Ryanuv", "de_Gaulluv"
                my $prefix = $1;
                $t_lemma = lc($prefix) . "_" . $a_lex_node->lemma;
            }
        }

    }

    my ($auxt) = grep { $_->afun eq "AuxT" } $t_node->get_aux_anodes;    # reflexiva tantum: smiať_sa
    if ( $auxt and not any { $_->lemma eq 'dať' } $t_node->get_aux_anodes ) {     # filter out modal 'dát sa'
        $t_lemma .= "_" . lc( $auxt->form );                                    
    }

    $t_node->set_t_lemma($t_lemma);

    return;
}

1;


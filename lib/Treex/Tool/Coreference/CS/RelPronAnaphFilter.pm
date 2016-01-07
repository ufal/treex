##########################################
######## THIS MODULE IS OBSOLETE #########
########### SHOULD BE DELETED ############
##########################################
package Treex::Tool::Coreference::CS::RelPronAnaphFilter;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

with 'Treex::Tool::Coreference::NodeFilter';

sub is_candidate {
    my ($self, $t_node) = @_;
    return is_relat($t_node);
}

#my %relat_lemmas = map {$_ => 1}
#    qw/co což jak jaký jenž již kam kde kdo kdy kolik který odkud/;

sub is_relat {
    my ($tnode) = @_;

    my $indeftype = $tnode->gram_indeftype;
    return (defined $indeftype && $indeftype eq "relat") ? 1 : 0;
    #if (defined $indeftype) {
    #    return ($indeftype eq "relat") ? 1 : 0;
    #}

    #my $anode = $tnode->get_lex_anode;
    #return 0 if !$anode;
    
    # 1 = Relative possessive pronoun jehož, jejíž, ... (lit. whose in subordinate relative clause) 
    # 4 = Relative/interrogative pronoun with adjectival declension of both types (soft and hard) (jaký, který, čí, ..., lit. what, which, whose, ...) 
    # 9 = Relative pronoun jenž, již, ... after a preposition (n-: něhož, niž, ..., lit. who)
    # E = Relative pronoun což (corresponding to English which in subordinate clauses referring to a part of the preceding text) 
    # J = Relative pronoun jenž, již, ... not after a preposition (lit. who, whom) 
    # K = Relative/interrogative pronoun kdo (lit. who), incl. forms with affixes -ž and -s (affixes are distinguished by the category VAR (for -ž) and PERSON (for -s))
    # ? = Numeral kolik (lit. how many/how much)
    #my $has_relat_tag = ( $anode->tag =~ /^.[149EJK\?]/ );
    
    #my $is_relat_lemma = $relat_lemmas{Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma, 0)}; 
    
    #return $has_relat_tag || $is_relat_lemma;
    
    #return $is_relat_lemma;
}

# TODO doc

1;

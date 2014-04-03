package Treex::Tool::Coreference::NodeFilter::PersPron;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

with 'Treex::Tool::Coreference::NodeFilter';

my %BANNED_PRONS = map {$_ => 1} qw/
    i me my mine you your yours we us our ours one
/;

sub is_candidate {
    my ($self, $t_node) = @_;
    return is_relat($t_node);
}

sub is_pers {
    my ($tnode, $args) = @_;
    if ($tnode->language eq 'cs') {
        return _is_relat_cs($tnode, $args);
    }
    if ($tnode->language eq 'en') {
        my $is_pers = _is_pers_en($tnode, $args);
        if ($is_pers) {
            my $anode = $tnode->get_lex_anode;
            print "ALEMMA: " . $anode->lemma . "\n";
            print "AFORM: " . $anode->form . "\n";
        }
        return $is_pers;
    }
}

sub _is_relat_cs {
    my ($tnode) = @_;

    #my $is_via_indeftype = _is_relat_via_indeftype($tnode);
    #return ($is_via_indeftype ? 1 : 0);
    #if (defined $is_via_indeftype) {
    #    return $is_via_indeftype;
    #}

    my $has_relat_tag = _is_relat_cs_via_tag($tnode);
    my $is_relat_lemma = _is_relat_cs_via_lemma($tnode); 
    
    #return $has_relat_tag;
    return $has_relat_tag || $is_relat_lemma;
    
    #return $is_relat_lemma;
}


# possible args:
#   skip_nonref : skip personal pronouns that are labeled as non-referential
#   reflexive : include reflexive pronouns (default = 1)
sub _is_pers_en {
    my ($tnode, $args) = @_;

    if (!defined $args) {
        $args = {};
    }

    my $is_3rd_pers = 0;
    if ( defined $tnode->gram_person ) {
        $is_3rd_pers = ($tnode->gram_person eq '3');
    }
    else {
        my $anode = $tnode->get_lex_anode;
        return 0 if (!defined $anode);
        $is_3rd_pers = (!defined $BANNED_PRONS{$anode->lemma});
    }
    # skip nodes marked as non-referential
    my $is_refer = $tnode->wild->{referential};
    return (
        (!$args->{skip_nonref} || !defined $is_refer || ($is_refer == 1)) &&  # referential (if it's set)
        ($tnode->t_lemma eq '#PersPron') &&  # personal pronoun 
        $is_3rd_pers    # third person
    );
}

# TODO doc

1;

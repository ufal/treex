package Treex::Tool::Coreference::NodeFilter::PersPron;

########################################################
######## TODO: replace relat_cs with pers_cs ###########
########################################################

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

with 'Treex::Tool::Coreference::NodeFilter';

#my %BANNED_PRONS = map {$_ => 1} qw/
#    i me my mine myself you your yours yourself yourselves we us our ours ourselves one
#/;
my %THIRD_PERS_PRONS = map {$_ => 1} qw/
    he him his himself
    she her hers herself
    it its itself
    they them their theirs themselves
/;
my %PERS_PRONS_REFLEX = map {$_ => 1} qw/
    myself yourself himself herself itself ourselves yourselves themselves
/;

has 'args' => (is => "ro", isa => "HashRef", default => sub {{}});

sub is_candidate {
    my ($self, $tnode) = @_;
    return is_3rd_pers($tnode, $self->args);
}

sub is_3rd_pers {
    my ($tnode, $args) = @_;
    if ($tnode->language eq 'cs') {
        return _is_relat_cs($tnode, $args);
    }
    if ($tnode->language eq 'en') {
        my $is_pers = _is_3rd_pers_en($tnode, $args);
        #if ($is_pers) {
        #    my $anode = $tnode->get_lex_anode;
        #    print "ALEMMA: " . $anode->lemma . "\n";
        #    print "AFORM: " . $anode->form . "\n";
        #}
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
sub _is_3rd_pers_en {
    my ($tnode, $args) = @_;

    if (!defined $args) {
        $args = {};
    }
    
    # is in 3rd person
    my $is_3rd_pers = 0;
    if ( defined $tnode->gram_person ) {
        $is_3rd_pers = ($tnode->gram_person eq '3');
    }
    else {
        my $anode = $tnode->get_lex_anode;
        return 0 if (!defined $anode);
        $is_3rd_pers = (defined $THIRD_PERS_PRONS{$anode->lemma});
    }

    # skip non-referential
    my $ok_skip_nonref = 1;
    if ($args->{skip_nonref}) {
        my $is_refer = $tnode->wild->{referential};
        $ok_skip_nonref = !defined $is_refer || ($is_refer == 1);
    }

    # reflexive
    my $ok_reflexive = 1;
    if (defined $args->{reflexive}) {
        my $reflex = is_reflexive($tnode);
        $ok_reflexive = ($reflex xor !$args->{reflexive});
#        print STDERR "OK_REFLEXIVE: " . ($ok_reflexive ? 1 : 0) . "\n";
    }

    return (
        ($tnode->t_lemma eq '#PersPron') &&  # personal pronoun 
        $is_3rd_pers &&    # third person
        $ok_skip_nonref &&  # referential (if it's set)
        $ok_reflexive
    );
}

sub is_reflexive {
    my ($tnode) = @_;
    my $reflex = $tnode->get_attr('is_reflexive');
    my $anode = $tnode->get_lex_anode;
    return 0 if (!defined $anode);
    if (!defined $reflex) {
        $reflex = $PERS_PRONS_REFLEX{$anode->lemma};
    }
    return $reflex;
}

# TODO doc

1;

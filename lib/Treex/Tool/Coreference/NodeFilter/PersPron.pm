package Treex::Tool::Coreference::NodeFilter::PersPron;

use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use Treex::Tool::Coreference::NodeFilter::Utils qw/ternary_arg/;

#my %BANNED_PRONS = map {$_ => 1} qw/
#    i me my mine myself you your yours yourself yourselves we us our ours ourselves one
#/;
my %THIRD_PERS_PRONS = map {$_ => 1} qw/
    he him his himself
    she her hers herself
    it its itself
    they them their theirs themselves
/;
my %PERS_PRONS_REFLEX = (
    en => { map {$_ => 1} qw/
            myself yourself himself herself itself ourselves yourselves themselves
          /},
    cs => { map {$_ => 1} qw/
            se svůj
          /},
);

sub is_pers {
    my ($node, $args) = @_;
    $args //= {};

    if ($node->language eq 'cs') {
        return _is_pers_cs($node, $args);
    }
    if ($node->language eq 'en') {
        my $is_pers = _is_pers_en($node, $args);
        #if ($is_pers) {
        #    my $anode = $tnode->get_lex_anode;
        #    print "ALEMMA: " . $anode->lemma . "\n";
        #    print "AFORM: " . $anode->form . "\n";
        #}
        return $is_pers;
    }
    # other: Russian, German
    return _is_pers_prague($node, $args);
}

sub is_3rd_pers {
    my ($anode, $args) = @_;
    $args //= {};
    $args->{person_3rd} = 1;
    is_pers($anode, $args);
}

sub is_3rd_prodrop {
    my ($node, $args) = @_;
    $args //= {};
    if ($node->language eq 'cs' && $node->get_layer eq "t") {
        return _is_3rd_prodrop_cs_t($node, $args);
    }
}

#---------------- public auxiliary -----------------

sub is_reflexive {
    my ($node) = @_;
    my $anode;
    if ($node->get_layer eq "t") {
        my $t_reflex = $node->get_attr('is_reflexive');
        return $t_reflex if (defined $t_reflex);
        return 0 if ($node->nodetype ne 'complex');
        $anode = $node->get_lex_anode;
    }
    else {
        $anode = $node;
    }
    
    return 0 if (!defined $anode);
    my $lemma = $anode->lemma;
    if ($anode->language eq "cs") {
        $lemma = Treex::Tool::Lexicon::CS::truncate_lemma($lemma, 1);
    }
    return $PERS_PRONS_REFLEX{$anode->language}{$lemma};
}

sub is_possessive {
    my ($node) = @_;
    my $anode;
    if ($node->get_layer eq "t") {
        $anode = $node->get_lex_anode;
    }
    else {
        $anode = $node;
    }
    return 0 if (!defined $anode);
    if ($anode->language eq "en") {
        return $anode->tag eq 'PRP$';
    }
    elsif ($anode->language eq "ru") {
        return 1 if ($anode->tag =~ /^P[S8]/);
        return 1 if (lc($anode->lemma) eq "свой");
        return 1 if (lc($anode->form) eq "его");
        return 1 if (lc($anode->form) eq "её");
        return 1 if (lc($anode->form) eq "их");
    }
    else {
        # Czech, German
        return $anode->tag =~ /^.[18SU]/;
    }
}

###############################################################
############################## PRIVATE ########################
###############################################################

########################### CZECH #############################

#---------------- personal pronoun -----------------

# possible args:
#   skip_nonref : skip personal pronouns that are labeled as non-referential
#   reflexive : include reflexive pronouns (default = 1)
sub _is_pers_cs {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return _is_pers_cs_a($node, $args);
    }
    else {
        return _is_pers_cs_t($node, $args);
    }
}

sub _is_pers_cs_a {
    my ($anode, $args) = @_;

    # is pronoun
    my $is_perspron = $anode->tag =~ /^P[PHS05678]/;
    return 0 if (!$is_perspron);

    # is 3rd person
    my $arg_3rd_person = $args->{person_3rd} // 0;
    my $is_3rd_person = $anode->tag =~ /^.......3/;
    my $is_any_person = $anode->tag =~ /^.......[-X]/;
    return 0 if !ternary_arg($arg_3rd_person, $is_3rd_person) && !$is_any_person;

    # return only expressed by default
    my $expressed = $args->{expressed} // 1;
    return 0 if ($expressed < 0);
    
    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($anode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);

    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($anode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
   
    return 1;
}

sub _is_pers_cs_t {
    my ($tnode, $args) = @_;
        
    # personal pronoun 
    return 0 if ($tnode->t_lemma ne '#PersPron');

    # return only expressed by default
    my $arg_expressed = $args->{expressed} // 1;
    my $anode = $tnode->get_lex_anode;
    my $expressed = defined $anode;
    return 0 if !ternary_arg($arg_expressed, $expressed);
    #log_info "_is_3rd_pers_cs_t";

    
    # is in 3rd person
    my $arg_3rd_person = $args->{person_3rd} // 0;
    my $is_3rd_person = 0;
    my $is_any_person = 1;
    if ( defined $tnode->gram_person ) {
        $is_3rd_person = $tnode->gram_person eq '3';
        $is_any_person = $tnode->gram_person eq 'inher';
    }
    elsif (defined $anode) {
        $is_3rd_person = $anode->tag =~ /^.......3/;
        $is_any_person = $anode->tag =~ /^.......[-X]/;
    }
    return 0 if !ternary_arg($arg_3rd_person, $is_3rd_person) && !$is_any_person;
    #else {
    #    my $par = $tnode->get_parent;
    #    my $apar = $par->get_lex_anode;
    #    if (defined $apar) {
    #        my $person = substr $apar->tag, 7, 1;
    #        if ($person ne "-") {
    #            $is_3rd_pers = $person eq '3';
    #        }
    #    }
    #}
    #log_info $tnode->id . "\tis_3rd: " . ($is_3rd_pers?1:0);


    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($tnode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);
    
    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($tnode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
    
    # skip non-referential
    my $ok_skip_nonref = 1;
    if ($args->{skip_nonref}) {
        my $is_refer = $tnode->wild->{referential};
        $ok_skip_nonref = !defined $is_refer || ($is_refer == 1);
    }
    return $ok_skip_nonref; # referential (if it's set)
}

#---------------- 3rd person prodrop -----------------

# possible args:
# parent_pos = (v|v_expr|n) : what is the POS tag of the parent and if it is expressed
# functor = (ACT) : what is the semantic role of the prodrop
sub _is_3rd_prodrop_cs_t {
    my ($tnode, $args) = @_;

    # must be generated
    my $anode = $tnode->get_lex_anode;
    return 0 if ($anode);


    # is in 3rd person
    my $is_3rd_pers = 1;
    if ( defined $tnode->gram_person ) {
        $is_3rd_pers = ($tnode->gram_person eq '3' || $tnode->gram_person eq 'inher');
    }

    if (defined $args->{parent_pos}) {
        my ($par) = $tnode->get_eparents({or_topological => 1});
        return 0 if !ternary_arg($args->{parent_pos} =~ /_expr/ ? 1 : 0, !$par->is_generated);
        my $pos_value = $par->formeme // $par->gram_sempos // "undef";
        my $parent_pos = 
            $pos_value =~ /^n/ ? "n" : (
            $pos_value =~ /^v/ ? "v" : "other");
        return 0 if ($args->{parent_pos} !~ /$parent_pos/);
    }

    if (defined $args->{functor}) {
        my $functor = $tnode->functor;
        return 0 if ($args->{functor} !~ /$functor/);
    }
    
    return (
        ($tnode->t_lemma eq '#PersPron') &&  # personal pronoun 
        $is_3rd_pers    # third person
    );
}

########################### ENGLISH #############################

# possible args:
#   skip_nonref : skip personal pronouns that are labeled as non-referential
#   reflexive : include reflexive pronouns (default = 1)
sub _is_pers_en {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return _is_pers_en_a($node, $args);
    }
    else {
        return _is_pers_en_t($node, $args);
    }
}

sub _is_pers_en_t {
    my ($tnode, $args) = @_;
        
    # personal pronoun 
    return 0 if ($tnode->t_lemma ne '#PersPron');

    # is expressed on the surface
    my $arg_expressed = $args->{expressed} // 1;
    my $anode = $tnode->get_lex_anode;
    my $expressed = defined $anode;
    return 0 if !ternary_arg($arg_expressed, $expressed);
    
    # is in 3rd person
    # by default generated #PersPron with no gram_person set are in 3rd person
    my $arg_3rd_person = $args->{person_3rd} // 0;
    my $is_3rd_person = 1;
    if ( defined $tnode->gram_person ) {
        $is_3rd_person = $tnode->gram_person eq '3';
    }
    elsif (defined $anode) {
        $is_3rd_person = defined $THIRD_PERS_PRONS{$anode->lemma};
    }
    return 0 if !ternary_arg($arg_3rd_person, $is_3rd_person);

    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($tnode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);
    
    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($tnode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
    
    # skip non-referential
    my $ok_skip_nonref = 1;
    if ($args->{skip_nonref}) {
        my $is_refer = $tnode->wild->{referential};
        $ok_skip_nonref = !defined $is_refer || ($is_refer == 1);
    }
    return $ok_skip_nonref;  # referential (if it's set)
}

sub _is_pers_en_a {
    my ($anode, $args) = @_;
    
    # is central (sometimes called personal)  pronoun
    return 0 if ($anode->tag !~ /^PRP/);
    
    # is in third person
    my $arg_3rd_person = $args->{person_3rd} // 0;
    my $is_3rd_person = $THIRD_PERS_PRONS{$anode->lemma};
    return 0 if !ternary_arg($arg_3rd_person, $is_3rd_person);
    
    # return only expressed by default
    my $expressed = $args->{expressed} // 1;
    return 0 if ($expressed < 0);
    
    # reflexive
    my $arg_reflexive = $args->{reflexive} // 0;
    my $reflexive = is_reflexive($anode);
    return 0 if !ternary_arg($arg_reflexive, $reflexive);

    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($anode);
    return 0 if !ternary_arg($arg_possessive, $possessive);
   
    return 1;
}

########################### PRAGUE STYLE GENERAL #############################
########################### RUSSIAN, GERMAN #############################

sub _is_pers_prague {
    my ($node, $args) = @_;
    if ($node->get_layer eq "a") {
        return _is_pers_prague_a($node, $args);
    }
    if ($node->get_layer eq "t") {
        return _is_pers_prague_t($node, $args);
    }
}

sub _is_pers_prague_t {
    my ($tnode, $args) = @_;
    my $anode = $tnode->get_lex_anode;
    return 0 if !$anode;
    return _is_pers_prague_a($anode, $args);
}

sub _is_pers_prague_a {
    my ($anode, $args) = @_;
    
    # is pronoun
    my $is_pron = ($anode->tag =~ /^P[PS568]/);
    return 0 if (!$is_pron);
    
    # is central pronoun in a 3rd person
    my $arg_3rd_person = $args->{person_3rd} // 0;
    my $is_3rd_person = $anode->tag =~ /^.......3/;
    my $is_any_person = $anode->tag =~ /^.......[-X]/;
    return 0 if !ternary_arg($arg_3rd_person, $is_3rd_person) && !$is_any_person;
    
    # return only expressed by default
    my $expressed = $args->{expressed} // 1;
    return 0 if ($expressed < 0);

    # possessive
    my $arg_possessive = $args->{possessive} // 0;
    my $possessive = is_possessive($anode);
    return 0 if !ternary_arg($arg_possessive, $possessive);

    return 1;
}

# TODO doc

1;

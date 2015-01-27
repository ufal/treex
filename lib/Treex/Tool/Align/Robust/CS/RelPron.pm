package Treex::Tool::Align::Robust::CS::RelPron;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Align::Utils;
use Treex::Tool::Coreference::NodeFilter::RelPron;
use Treex::Tool::Align::Robust::Common;

sub access_via_alayer {
    my ($tnode, $align_filters, $errors) = @_;
    my $anode = $tnode->get_lex_anode();
    my @aligned_anodes = Treex::Tool::Align::Utils::aligned_transitively([$anode], $align_filters);
    if (!@aligned_anodes) {
        push @$errors, "NO_EN_REF_ANODE";
        return;
    }
    # the node is not t-aligned => it doesn't have a lexical counterpart on the t-layer
    my @aligned_tnodes = map {$_->get_referencing_nodes('a/aux.rf')} @aligned_anodes;
    #log_info "NO_AUX: " . $tnode->get_address;
    return @aligned_tnodes;
}

sub filter_anodes {
    my ($aligned, $tnode, $errors) = @_;
    my @filtered_a = ();
    my @filtered_t = ();
    foreach my $ali_t (@$aligned) {
        my @wh_a = grep {$_->tag =~ /^W/} $ali_t->get_aux_anodes();
        if (@wh_a) {
            push @filtered_t, $ali_t;
            push @filtered_a, @wh_a;
        }
    }
    if (!@filtered_a) {
        push @$errors, "NO_WH_PRON_ANODE";
        return;
    }
    my $anodes_str = join ",", (map {$_->id} @filtered_a);
    push @$errors, "WH_PRON_ANODE=$anodes_str";
    #print STDERR "FILTER_ANODES: " . $filtered_a[0]->get_address . "\n" if (@filtered_a);
    print STDERR "A-NODE-WH-PRONOUN\t" . $tnode->get_address() . "\n";
    return @filtered_t;
}

sub filter_self {
    my ($aligned, $tnode, $errors) = @_;
    my @filtered = grep {Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($_)} @$aligned;
    if (!@filtered) {
        push @$errors, "NORELAT_EN_REF_TNODE";
        return;
    }
    #print STDERR "FILTER_SELF: " . $filtered[0]->get_address . "\n" if (@filtered);
    print STDERR "SELF-PRONOUN\t" . $tnode->get_address() . "\n";
    return @filtered;
}

sub filter_eparents {
    my ($aligned, $tnode, $errors) = @_;

    my @refer_to_grandpar_tnodes = grep {_is_coref_gram_to_grandpar($_)} @$aligned;
    
    if (@refer_to_grandpar_tnodes) {
        print STDERR "PARENTS-COREF-FUNCTOR_1\t" . $tnode->get_address() . "\n";
        return @refer_to_grandpar_tnodes;
    }

    my @functor_tnodes = Treex::Tool::Align::Robust::Common::filter_by_functor($aligned, $tnode->functor, $errors);

    if (!@functor_tnodes) {
        my @res = filter_by_coref($aligned, $errors);
        if (@res) {
            print STDERR "PARENTS-COREF-FUNCTOR_3\t" . $tnode->get_address() . "\n";
        }
        return @res;
    }
    my @filtered_functor_tnodes = grep {
        Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($_) || 
        $_->t_lemma eq "#Cor" || $_->t_lemma eq "#PersPron"
    } @functor_tnodes;
    if (!@filtered_functor_tnodes) {
        push @$errors, "BAD_EN_REF_FUNCTOR_TNODE";
        my @res = filter_by_coref($aligned, $errors);
        if (@res) {
            print STDERR "PARENTS-COREF-FUNCTOR_3\t" . $tnode->get_address() . "\n";
        }
        return @res;
    }
    print STDERR "PARENTS-COREF-FUNCTOR_2\t" . $tnode->get_address() . "\n";
    return @filtered_functor_tnodes;
}

sub filter_by_coref {
    my ($nodes, $errors) = @_;
    my @coref_nodes = grep {scalar($_->get_coref_gram_nodes) > 0} @$nodes;
    if (@coref_nodes == 0) {
        push @$errors, "NO_EN_REF_COREF_CHILDREN";
        return;
    }
    if (@coref_nodes > 1) {
        push @$errors, "MANY_EN_REF_COREF_CHILDREN";
        return;
    }
    return $coref_nodes[0];
}

sub filter_siblings {
    my ($aligned, $tnode, $errors) = @_;
    
    my $par = Treex::Tool::Align::Robust::Common::parents_of_aligned_siblings($aligned, $errors);
    return if (!$par);
   
    if (defined $par->functor && $par->functor eq "APPS") {
        push @$errors, "APPOS_SIBLINGS";
        print STDERR "SIBLINGS-FUNCTOR_APPOS\t" . $tnode->get_address() . "\n";
        return $par;
    }
    my $formeme = $par->formeme;
    if (!defined $formeme) {
        push @$errors, "NOFORMEME_EN_REF_PAR";
        return;
    }
    if ($formeme =~ /^n/) {
        push @$errors, "ALIGN=ANTE";
        my $child_info = join " ", map {$_->functor . "." . $_->formeme} @$aligned;
        push @$errors, "N $child_info";
        print STDERR "SIBLINGS-FUNCTOR_N-UNDIRECT\t" . $tnode->get_address() . "\n";
        return $par;
    }
    if ($formeme =~ /^v/) {
        my @refer_to_grandpar_tnodes = grep {_is_coref_gram_to_grandpar($_)} $par->get_children;
        if (@refer_to_grandpar_tnodes) {
            print STDERR "SIBLINGS-FUNCTOR_1\t" . $tnode->get_address() . "\n";
            return @refer_to_grandpar_tnodes;
        }

        my ($relat_child) = grep {Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($_)} $par->get_children();
        if (defined $relat_child) {
            print STDERR "SIBLINGS-FUNCTOR_2\t" . $tnode->get_address() . "\n";
            return $relat_child;
        }
        
        my @cor_children = grep {$_->t_lemma eq "#Cor"} $par->get_children();
        if (@cor_children == 1) {
            print STDERR "SIBLINGS-FUNCTOR_3\t" . $tnode->get_address() . "\n";
            return $cor_children[0];
        }

        push @$errors, "ALIGN=ANTE";
        my $child_info = join " ", map {$_->functor . "." . $_->formeme} @$aligned;
        push @$errors, "V $child_info";
        print STDERR "SIBLINGS-FUNCTOR_V-UNDIRECT\t" . $tnode->get_address() . "\n";
        return $par;
    }
    push @$errors, "BADFORMEME_EN_REF_PAR";
    return;
}

sub select_via_self_siblings {
    my ($tnode, $align_filters, $errors) = @_;
    my @self_sibs = ($tnode, $tnode->get_siblings);
    my @aligned = Treex::Tool::Align::Utils::aligned_transitively(\@self_sibs, $align_filters);
    if (!@aligned) {
        push @$errors, "NO_ALIGN_SELF_SIBLING";
        return;
    }
    return @aligned;
}

sub filter_appos {
    my ($aligned, $tnode, $errors) = @_;
    my @pars = map {$_->get_parent} @$aligned;
    my @emp_verb = grep {defined $_->t_lemma && $_->t_lemma eq "#EmpVerb"} @pars;
    my @appos = grep {defined $_->functor && $_->functor eq "APPS"} @pars;
    if (@appos) {
        push @$errors, "APPOS_DIRECT";
        print STDERR "SELF-SIBLINGS-APPS-EMPVERB_APPOS\t" . $tnode->get_address() . "\n";
        return $appos[0];
    }
    if (@emp_verb) {
        my $emp_verb_par = $emp_verb[0]->get_parent;
        if (defined $emp_verb_par->functor && $emp_verb_par->functor eq "APPS") {
            push @$errors, "APPOS_EMPVERB";
            print STDERR "SELF-SIBLINGS-APPS-EMPVERB_APPOS-EMPVERB\t" . $tnode->get_address() . "\n";
            return $emp_verb_par;
        }
        if (defined $emp_verb_par->formeme && $emp_verb_par->formeme =~ /^([nv])/) {
            my $pos = uc($1);
        
            push @$errors, "ALIGN=ANTE";
            push @$errors, $pos. " " .$emp_verb[0]->functor. "." .$emp_verb[0]->formeme;
            print STDERR "SELF-SIBLINGS-APPS-EMPVERB_UNDIRECT-NV-EMPVERB\t" . $tnode->get_address() . "\n";
            return $emp_verb_par;
        }
        push @$errors, "EMPVERB_BAD_FORMEME";
        return;
    }
    #my ($cs_ref_par) = $cs_ref_tnode->get_eparents({or_topological => 1});
    #if ($cs_ref_par->t_lemma ne "být") {
    #    return "NO_VERB_APPOS_NOBYT";
    #}
    push @$errors, "NO_EMPVERB_APPOS";
    return;
}

sub _is_coref_gram_to_grandpar {
    my ($tnode) = @_;
    my $grandpar = $tnode;
    for (my $i = 0; $i < 2; $i++) {
        $grandpar = $grandpar->get_parent;
        return 0 if (!defined $grandpar);
    }
    my @coref_gram = $tnode->get_coref_gram_nodes();
    return any {$_ == $grandpar} @coref_gram;
}


1;

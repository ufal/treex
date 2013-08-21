package Treex::Block::Print::ItTranslData;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'data_type' => ( isa => enum([qw/pcedt czeng/]), is => 'ro', required => 1, default => 'pcedt' );

sub _get_aligned_nodes_pcedt {
    my ($self, $tnode) = @_;

    my ($t_csrefs, $t_has_enref) = $self->_csrefs_from_ensrc($tnode);
    
    return ($t_csrefs, undef) if (!defined $t_has_enref);
    return ([], undef) if ($t_has_enref);
        
    my $anode = $tnode->get_lex_anode;
    my ($a_csrefs, $a_has_enref) = $self->_csrefs_from_ensrc($anode);
    
    log_warn "NO_A_MONOALIGN: this should not happen (" . $tnode->get_address . ")\n" if (defined $a_has_enref && ($a_has_enref == 0));

    return (undef, $a_csrefs);

}

sub _csrefs_from_ensrc {
    my ($self, $ensrc) = @_;
    
    my @enrefs = grep {$_->is_aligned_to($ensrc, 'monolingual')} $ensrc->get_referencing_nodes('alignment');
    return ([], 0) if ( @enrefs == 0 );
    
    my ($aligns, $type) = $enrefs[0]->get_aligned_nodes;
    return ([], 1) if (!$aligns || !$type);
        
    my @csrefs = map {$aligns->[$_]} grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    return (\@csrefs);
}

sub _get_aligned_nodes_czeng {
    my ($self, $tnode) = @_;

    my @cs_src = grep {!$_->is_aligned_to($tnode, 'monolingual')} $tnode->get_referencing_nodes('alignment');
    return @cs_src;
}

sub get_class_pcedt {
    my ($self, $tnode) = @_;

    my $class;

    my ($aligned_t, $aligned_a) = $self->_get_aligned_nodes_pcedt($tnode);
    if ($aligned_t) {
        $class = "<" . (join ":", map {$_->t_lemma} @$aligned_t) . ">";
    } elsif ($aligned_a) {
        $class = "<alemmas=<" . (join ":", map {$_->lemma} @$aligned_a) . ">>";
    }
    return $class;
}

sub get_class_czeng {
    my ($self, $tnode) = @_;
    my @aligned = $self->_get_aligned_nodes_czeng($tnode);
    my $class = "<" . (join ":", map {$_->t_lemma} @aligned) . ">";
    return $class;
}

sub get_class {
    my ($self, $tnode) = @_;
    
    if ($self->data_type eq 'pcedt') {
        return $self->get_class_pcedt($tnode);
    } else {
        return $self->get_class_czeng($tnode);
    }
    #print STDERR "CLASS: $class; " . $tnode->get_address . "\n";
    #return $class;
}

# for a given "it" in src, returns the t-lemma of a node from cs_ref,
# which has the same functor and both are governed by mutually aligned nodes (verbs)
# can be used only on analysed PCEDT
sub _get_gold_counterpart_tlemma {
    my ($self, $ensrc_it) = @_;
    
    my $a_ensrc_it = $ensrc_it->get_lex_anode;
    my ($a_enref_it) = grep {$_->is_aligned_to($a_ensrc_it, 'monolingual')} $a_ensrc_it->get_referencing_nodes('alignment');
    return "__NO_A_ENREF__" if !$a_enref_it;
    my ($enref_it) = $a_enref_it->get_referencing_nodes('a/lex.rf');
    return "__NO_T_ENREF__" if !$enref_it;

    my ($enref_par) = grep {$_->formeme && ($_->formeme =~ /^v/)} $enref_it->get_eparents;
    return "__NO_V_ENREF_PAR__" if !$enref_par;
    my ($aligns, $type) = $enref_par->get_aligned_nodes;
    return "__NO_CSREF_PAR__" if (!$aligns || !$type);
        
    my ($csref_par) = grep {$_->formeme =~ /^v/} map {$aligns->[$_]} grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    return $self->_gold_counterpart_tlemma_via_alayer($a_enref_it, $enref_it) if !$csref_par;

    my ($csref_it) = grep {$_->functor eq $enref_it->functor} $csref_par->get_echildren;
    return "__NO_CSREF__" if !$csref_it;
    return $csref_it->t_lemma;
}

sub _gold_counterpart_tlemma_via_alayer {
    my ($self, $a_enref_it, $enref_it) = @_;

    my ($a_enref_par) = grep {defined $_->tag && ($_->tag =~ /^V/)} $a_enref_it->get_eparents;
    return "__A:NO_A_V_ENREF_PAR__" if !$a_enref_par;

    my ($aligns, $type) = $a_enref_par->get_aligned_nodes;
    return "__A:NO_A_CSREF_PAR1__" if (!$aligns || !$type);
    my ($a_csref_par) = map {$aligns->[$_]} grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    return "__A:NO_A_CSREF_PAR2__" if !$a_csref_par;
    my ($csref_par) = $a_csref_par->get_referencing_nodes('a/lex.rf');
    return "__A:NO_CSREF_PAR__" if !$csref_par;

    my ($csref_it) = grep {$_->functor eq $enref_it->functor} $csref_par->get_echildren({or_topological => 1});
    return "__A:NO_CSREF__" if !$csref_it;
    return "A:".$csref_it->t_lemma;
}

sub _get_nada_refer {
    my ($tnode) = @_;
    my $refer = $tnode->wild->{'referential'};
    return '__UNDEF__' if (!defined $refer);
    return $refer;
}

sub _get_parent_lemma {
    my ($tnode) = @_;
    my $par = $tnode->get_parent;
    if ($par->is_root) {
        return "__ROOT__";
    }
    return $par->t_lemma;
}

sub _it_subj {
    my ($tnode) = @_;
    return $tnode->formeme =~ /subj/ ? 1 : 0;
}

sub _sibl_obj {
    my ($tnode) = @_;
    my ($sibl) = grep {$_->formeme =~ /obj/} $tnode->get_siblings;
    return $sibl ? 1 : 0;
}

sub _cleft {
    my ($tnode, $approx) = @_;
    my $it_subj_be = _it_subj($tnode) && (_get_parent_lemma($tnode) eq "be");
    return 0 if !$it_subj_be;
    
    my ($obj) = grep {$_->formeme =~ /obj/} $tnode->get_siblings;
    return 0 if !$obj;

    my @rc_cands;
    if ($approx) {
        @rc_cands = grep {$_->get_depth - $obj->get_depth < 3} $obj->get_descendants
    } else {  
        @rc_cands = $obj->get_echildren;
    }
    my ($rc) = grep {$_->formeme eq "v:rc"} @rc_cands;
    return $rc ? 1 : 0;
}

sub _be_adjcompl {
    my ($tnode) = @_;
    my $it_subj_be = _it_subj($tnode) && (_get_parent_lemma($tnode) eq "be");
    return 0 if !$it_subj_be;
    
    my ($adjcompl) = grep {$_->formeme =~ /adj:compl/} $tnode->get_siblings;
    return $adjcompl ? 1 : 0;
}

sub _be_adjcompl_that {
    my ($tnode) = @_;
    my $adjcompl = _be_adjcompl($tnode);

    my ($vthat) = grep {$_->formeme =~ /v:that/} $tnode->get_siblings;
    return ($adjcompl && $vthat) ? 1 : 0;
}

sub get_features {
    my ($self, $tnode) = @_;

    my %feats = ();

    ######### FEATURES #############
    
    $feats{gcp} = $self->_get_gold_counterpart_tlemma($tnode);

    $feats{nada_refer} = _get_nada_refer($tnode);
    $feats{par_lemma} = _get_parent_lemma($tnode);
    
    $feats{par_be} = $feats{par_lemma} eq "be" ? 1 : 0;
    $feats{it_subj} = _it_subj($tnode);
    $feats{it_subj_be} = $feats{it_subj} && $feats{par_be} ? 1 : 0;
    $feats{it_subj_be} = $feats{it_subj} && $feats{par_be} ? 1 : 0;
    $feats{sibl_obj} = _sibl_obj($tnode);
    $feats{it_subj_be_obj} = $feats{it_subj_be} && $feats{sibl_obj} ? 1 : 0;

    # cleft sentences:
    # But it is Mr. Lane, as movie director, producer and writer, who has been obsessed with refitting Chaplin's Little Tramp in a contemporary way.
    # Then an announcer interjects: ``It was Douglas Wilder who introduced a bill to force rape victims age 13 and younger to be interrogated about their private lives by lawyers for accused rapists.
    # And most disturbing, it is educators, not students, who are blamed for much of the wrongdoing.
    $feats{cleft} = _cleft($tnode, 0);
    $feats{cleft_approx} = _cleft($tnode, 1);

    # it + be + adj:compl + v:that+fin
    # If the banks exhaust all avenues of appeal, it is possible that they would seek to have the illegality ruling work both ways, some market sources said .
    $feats{be_adjcompl} = _be_adjcompl($tnode);
    $feats{be_adjcompl_that} = _be_adjcompl_that($tnode);

    # TODO:many more features

    ###############################
    my @feat_list = map {$_ . "=" . $feats{$_}} sort keys %feats;

    my $address = $tnode->get_address;
    return ("address=$address", @feat_list);
}

sub process_tnode {
    my ($self, $tnode) = @_;
    
    return if ($tnode->t_lemma ne "#PersPron");

    # TRANSLATION OF "IT" - can be possibly left out => translation of "#PersPron"
    my $anode = $tnode->get_lex_anode;
    return if (!$anode || ($anode->lemma ne "it"));

    my $class = $self->get_class($tnode);
    my @features = $self->get_features($tnode);

    print $class . "\t" . (join " ", @features) . "\n";
}

1;

# TODO POD

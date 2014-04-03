package Treex::Tool::Coreference::Features::TectoSyntax;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::CorefFeatures';

##### TODO remove this ################
my $b_true = '1';
my $b_false = '-1';
#######################################

my %actants = map { $_ => 1 } qw/ACT PAT ADDR APP/;

sub binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;
    
    my $coref_features = {};
    
    # are_siblings
    $coref_features->{b_sibl} = _are_siblings( $cand, $anaph );
    
    # formeme
    $coref_features->{b_fmm_agree} 
        = $self->_agree_feats($set_features->{c_cand_fmm}, $set_features->{c_anaph_fmm});
    $coref_features->{c_join_fmm}  
        = $self->_join_feats($set_features->{c_cand_fmm}, $set_features->{c_anaph_fmm});

    # analytical functor
    $coref_features->{b_afun_agree} 
        = $self->_agree_feats($set_features->{c_cand_afun}, $set_features->{c_anaph_afun});
    $coref_features->{c_join_afun}  
        = $self->_join_feats($set_features->{c_cand_afun}, $set_features->{c_anaph_afun});
    
    # if it's a subject
    $coref_features->{b_subj_agree} 
        = $self->_agree_feats($set_features->{b_cand_subj}, $set_features->{b_anaph_subj});
    
    # tectogrammatical functor
    $coref_features->{b_fun_agree} 
        = $self->_agree_feats($set_features->{c_cand_fun}, $set_features->{c_anaph_fun});
    $coref_features->{c_join_fun}  
        = $self->_join_feats($set_features->{c_cand_fun}, $set_features->{c_anaph_fun});
    
    # is aktant
    $coref_features->{b_akt_agree} 
        = $self->_agree_feats($set_features->{b_cand_akt}, $set_features->{b_anaph_akt});
    
    # is in coordination
    $coref_features->{b_app_in_coord} = _is_app_in_coord( $cand, $anaph );
    
    # tfa
    $coref_features->{b_tfa_agree} 
        = $self->_agree_feats($set_features->{c_cand_tfa}, $set_features->{c_anaph_tfa});
    $coref_features->{c_join_tfa}  
        = $self->_join_feats($set_features->{c_cand_tfa}, $set_features->{c_anaph_tfa});
    
    
    ##################   Context #########################
    # get candidate and anaphor eparent functor and sempos
    # agreement in eparent functor and sempos
    $coref_features->{b_epar_fmm_agree}
        = $self->_agree_feats($set_features->{c_cand_epar_fmm}, $set_features->{c_anaph_epar_fmm});
    $coref_features->{c_join_epar_fmm}          
        = $self->_join_feats($set_features->{c_cand_epar_fmm}, $set_features->{c_anaph_epar_fmm});
    $coref_features->{b_epar_fun_agree}
        = $self->_agree_feats($set_features->{c_cand_epar_fun}, $set_features->{c_anaph_epar_fun});
    $coref_features->{c_join_epar_fun}          
        = $self->_join_feats($set_features->{c_cand_epar_fun}, $set_features->{c_anaph_epar_fun});
    $coref_features->{b_epar_sempos_agree}      
        = $self->_agree_feats($set_features->{c_cand_epar_sempos}, $set_features->{c_anaph_epar_sempos});
    $coref_features->{c_join_epar_sempos}       
        = $self->_join_feats($set_features->{c_cand_epar_sempos}, $set_features->{c_anaph_epar_sempos});
    $coref_features->{b_epar_lemma_agree}       
        = $self->_agree_feats($set_features->{c_cand_epar_lemma}, $set_features->{c_anaph_epar_lemma});
    $coref_features->{c_join_epar_lemma}        
        = $self->_join_feats($set_features->{c_cand_epar_lemma}, $set_features->{c_anaph_epar_lemma});
    $coref_features->{c_join_clemma_aeparlemma} 
        = $self->_join_feats($cand->t_lemma, $set_features->{c_anaph_epar_lemma});

    return $coref_features;
}

sub unary_features {
    my ($self, $node, $type) = @_;
    
    my $coref_features = {};
    
    # formeme
    $coref_features->{'c_'.$type.'_fmm'}  = $node->formeme;
    
    # analytical functor
    $coref_features->{'c_'.$type.'_afun'}  = _get_afun($node);
    
    # is subject
    $coref_features->{'b_'.$type.'_subj'}  = _is_subject($node);
    
    # functor
    $coref_features->{'c_'.$type.'_fun'}  = $node->functor;
    
    # aktant
    $coref_features->{'b_'.$type.'_akt'}  = $actants{ $node->functor  } ? $b_true : $b_false;
    
    # in coordination
    if ($type eq 'cand') {
        $coref_features->{b_cand_coord} = ( $node->is_member ) ? $b_true : $b_false;
    }
    
    # tfa
    $coref_features->{'c_'.$type.'_tfa'}  = $node->tfa;
    
    ##################   Context #########################
    # get candidate and anaphor eparent functor and sempos
    # agreement in eparent functor and sempos
    ( $coref_features->{'c_'.$type.'_epar_fun'},  $coref_features->{'c_'.$type.'_epar_sempos'},
        $coref_features->{'c_'.$type.'_epar_fmm'}, $coref_features->{'c_'.$type.'_epar_lemma'})  = _get_eparent_features($node);
    
    return $coref_features;
}

# returns $b_true if the parameter is subject; otherwise $b_false
sub _is_subject {
	my ($node) = @_;
	my $par = ($node->get_eparents)[0];
    return $b_false if (!defined $par || $par->is_root);
	
    if ($par->gram_tense && ($par->gram_tense =~ /^(sim|ant|post)/) || 
        ($par->functor eq 'DENOM')) {
		
        my @cands = $par->get_echildren;
 		my @sb_ids;
		foreach my $child (@cands) {
			if (defined $child->gram_sempos && ($child->gram_sempos =~ /^n/)) {
                my $achild = $child->get_lex_anode;
                if (defined $achild && ($achild->afun eq 'Sb')) {
					push @sb_ids, $child->id;
				}
			}
		}

        if ((@sb_ids == 0) && ($node->functor eq 'ACT')) {
			return $b_true;
        }
        my %subj_hash = map {$_ => 1} @sb_ids; 
		if (defined $subj_hash{$node->id}) { 
			return $b_true;
		}	
	}
	return $b_false;
}

# returns if $inode and $jnode have the same eparent
sub _are_siblings {
	my ($inode, $jnode) = @_;
	my $ipar = ($inode->get_eparents)[0];
	my $jpar = ($jnode->get_eparents)[0];
	return ($ipar == $jpar) ? $b_true : $b_false;
}

# returns the first eparent's functor, sempos, formeme and lemma
sub _get_eparent_features {
	my ($node) = @_;
# 	my $epar = ($node->get_eparents)[0];
	if ( my $epar = ($node->get_eparents)[0] ) {
        return ($epar->functor, $epar->gram_sempos, $epar->formeme, $epar->t_lemma);
	}
	return;
}

# returns whether an anaphor is APP and is in the same clause with a
# candidate and they have a common (grand)parent CONJ|DISJ
sub _is_app_in_coord {
	my ($cand, $anaph) = @_;
	if ($anaph->functor eq 'APP' && 
        ($anaph->wild->{aca_clausenum} eq $cand->wild->{aca_clausenum})) {
		
        my $par = $anaph->parent;
		while ($par && ($par != $cand) && !$par->is_root && 
            (!$par->gram_tense || $par->gram_tense !~ /^(sim|ant|post)/) && 
            (!$par->functor || $par->functor !~ /^(PRED|DENOM)$/)) {

            if ($par->functor =~ /^(CONJ|DISJ)$/) {
				return (grep {$_ eq $cand} $par->descendants) ? $b_true : $b_false;
			}
			$par = $par->parent;
		}
	}
	return $b_false;
}



# returns the function of an analytical node $node
sub _get_afun {
	my ($node) = @_;
	my $anode = $node->get_lex_anode;
    if ($anode) {
		return $anode->afun;
	}
    return;
}

1;

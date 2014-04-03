package Treex::Tool::Coreference::PronCorefFeatures;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::CorefFeatures';

my $b_true = '1';
my $b_false = '-1';

my %actants = map { $_ => 1 } qw/ACT PAT ADDR APP/;

#sub _build_feature_names {
#    my ($self) = @_;
#    return log_fatal "method _build_feature_names must be overriden in " . ref($self);
#}

sub _ante_loc_buck {
    my ($self, $anaph, $cand, $sent_dist) = @_;

    my $pos = $cand->ord;
    if ($sent_dist == 0) {
        $pos = $anaph->ord - $cand->ord;
    }
    return _categorize( $pos, [0, 3, 5, 9, 17, 33] );
}

sub _anaph_loc_buck {
    my ($self, $anaph) = @_;
    return _categorize( $anaph->ord, [0, 3, 5, 9] );
}

sub _binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my $coref_features = {};

###########################
    #   Distance:
    #   4x num: sentence distance, clause distance, file deepord distance, candidate's order
    $coref_features->{c_sent_dist} =
        $anaph->get_bundle->get_position - $cand->get_bundle->get_position;
    $coref_features->{c_clause_dist} = _categorize(
        $anaph->wild->{aca_clausenum} - $cand->wild->{aca_clausenum}, 
        [-2, -1, 0, 1, 2, 3, 7]
    );
    $coref_features->{c_file_deepord_dist} = _categorize(
        $anaph->wild->{doc_ord} - $cand->wild->{doc_ord},
        [1, 2, 3, 6, 15, 25, 40, 50]
    );
    $coref_features->{c_cand_ord} = _categorize(
        $candord,
        [1, 2, 3, 5, 8, 11, 17, 22]
    );
    #$coref_features->{c_cand_ord} = $candord;

    # a feature from (Charniak and Elsner, 2009)
    # this antecedent position depends on the location of antecedent, thus placed among binary features
    $coref_features->{c_cand_loc_buck} = $self->_ante_loc_buck($anaph, $cand, $coref_features->{c_sent_dist});

    #   24: 8 x tag($inode, $jnode), joined
    
    $coref_features->{c_join_apos}  
        = $self->_join_feats($set_features->{c_cand_apos}, $set_features->{c_anaph_apos});
    $coref_features->{c_join_anum}  
        = $self->_join_feats($set_features->{c_cand_anum}, $set_features->{c_anaph_anum});

###########################
    #   Functional:
    #   3:  functor($inode, $jnode);
    $coref_features->{b_fun_agree} 
        = $self->_agree_feats($set_features->{c_cand_fun}, $set_features->{c_anaph_fun});
    $coref_features->{c_join_fun}  
        = $self->_join_feats($set_features->{c_cand_fun}, $set_features->{c_anaph_fun});

    #   formeme
    $coref_features->{b_fmm_agree} 
        = $self->_agree_feats($set_features->{c_cand_fmm}, $set_features->{c_anaph_fmm});
    $coref_features->{c_join_fmm}  
        = $self->_join_feats($set_features->{c_cand_fmm}, $set_features->{c_anaph_fmm});
    
    #   3: afun($inode, $jnode);
    $coref_features->{b_afun_agree} 
        = $self->_agree_feats($set_features->{c_cand_afun}, $set_features->{c_anaph_afun});
    $coref_features->{c_join_afun}  
        = $self->_join_feats($set_features->{c_cand_afun}, $set_features->{c_anaph_afun});
    
    #   3: aktant($inode, $jnode);
    $coref_features->{b_akt_agree} 
        = $self->_agree_feats($set_features->{b_cand_akt}, $set_features->{b_anaph_akt});
    
    #   3:  subject($inode, $jnode);
    $coref_features->{b_subj_agree} 
        = $self->_agree_feats($set_features->{b_cand_subj}, $set_features->{b_anaph_subj});
    
    #   Context:
    $coref_features->{b_app_in_coord} = _is_app_in_coord( $cand, $anaph );
    
    #   4: get candidate and anaphor eparent functor and sempos
    #   2: agreement in eparent functor and sempos
	#my ($anaph_epar_lemma, $cand_epar_lemma) = map {my $epar = ($_->get_eparents)[0]; $epar->t_lemma} ($anaph, $cand);
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
        #= $self->_agree_feats($cand_epar_lemma, $anaph_epar_lemma);
        = $self->_agree_feats($set_features->{c_cand_epar_lemma}, $set_features->{c_anaph_epar_lemma});
    $coref_features->{c_join_epar_lemma}        
        #= $self->_join_feats($cand_epar_lemma, $anaph_epar_lemma);
        = $self->_join_feats($set_features->{c_cand_epar_lemma}, $set_features->{c_anaph_epar_lemma});
    $coref_features->{c_join_clemma_aeparlemma} 
        #= $self->_join_feats($cand->t_lemma, $anaph_epar_lemma);
        = $self->_join_feats($cand->t_lemma, $set_features->{c_anaph_epar_lemma});
    
    #   3:  tfa($inode, $jnode);
    $coref_features->{b_tfa_agree} 
        = $self->_agree_feats($set_features->{c_cand_tfa}, $set_features->{c_anaph_tfa});
    $coref_features->{c_join_tfa}  
        = $self->_join_feats($set_features->{c_cand_tfa}, $set_features->{c_anaph_tfa});
    
    #   1: are_siblings($inode, $jnode)
    $coref_features->{b_sibl} = _are_siblings( $cand, $anaph );

    return $coref_features;
}

sub _unary_features {
    my ($self, $node, $type) = @_;

    my $coref_features = {};

    return if (($type ne 'cand') && ($type ne 'anaph'));

    #   1: anaphor's ID
    $coref_features->{$type.'_id'} = $node->get_address;

    if ($type eq 'anaph') {
        $coref_features->{c_anaph_sentord} = _categorize(
            $node->get_root->wild->{czeng_sentord},
            [0, 1, 2, 3]
        );
        
        # a feature from (Charniak and Elsner, 2009)
        $coref_features->{c_anaph_loc_buck} = $self->_anaph_loc_buck($node);
    }

###########################
    #   Functional:
    #   2:  formeme
    $coref_features->{'c_'.$type.'_fmm'}  = $node->formeme;

    #   3:  functor($inode, $jnode);
    $coref_features->{'c_'.$type.'_fun'}  = $node->functor;
    
    #   3: afun($inode, $jnode);
    $coref_features->{'c_'.$type.'_afun'}  = _get_afun($node);
    
    #   3: aktant($inode, $jnode);
    $coref_features->{'b_'.$type.'_akt'}  = $actants{ $node->functor  } ? $b_true : $b_false;
    
    #   3:  subject($inode, $jnode);
    $coref_features->{'b_'.$type.'_subj'}  = _is_subject($node);
    
    #   Context:
    if ($type eq 'cand') {
        $coref_features->{b_cand_coord} = ( $node->is_member ) ? $b_true : $b_false;
    }
    
    #   4: get candidate and anaphor eparent functor and sempos
    #   2: agreement in eparent functor and sempos
    ( $coref_features->{'c_'.$type.'_epar_fun'},  $coref_features->{'c_'.$type.'_epar_sempos'},
        $coref_features->{'c_'.$type.'_epar_fmm'}, $coref_features->{'c_'.$type.'_epar_lemma'})  = _get_eparent_features($node);
# 	my $eparent = ($node->get_eparents)[0];
# 	$coref_features->{'c_'.$type.'_epar_lemma'} = $eparent->t_lemma;
    
    #   3:  tfa($inode, $jnode);
    $coref_features->{'c_'.$type.'_tfa'}  = $node->tfa;
    
    return $coref_features;
}

# returns if $inode and $jnode have the same eparent
sub _are_siblings {
	my ($inode, $jnode) = @_;
	my $ipar = ($inode->get_eparents({or_topological => 1}))[0];
	my $jpar = ($jnode->get_eparents({or_topological => 1}))[0];
	return ($ipar == $jpar) ? $b_true : $b_false;
}

# returns the first eparent's functor, sempos, formeme and lemma
sub _get_eparent_features {
	my ($node) = @_;
# 	my $epar = ($node->get_eparents)[0];
	if ( my $epar = ($node->get_eparents({or_topological => 1}))[0] ) {
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

# returns $b_true if the parameter is subject; otherwise $b_false
sub _is_subject {
	my ($node) = @_;
	my $par = ($node->get_eparents({or_topological => 1}))[0];
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
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::PronCorefFeatures

=head1 DESCRIPTION

An abstract class for features needed in personal pronoun coreference
resolution. The features extracted here should be language independent.

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

#=item _build_feature_names 
#
#A list of features required for training/resolution. Without implementing 
#in a subclass it throws an exception.

=back

=head2 Already implemented

=over

=item _unary_features

It returns a hash of unary features that relate either to the anaphor or the
antecedent candidate. 

Contains just language-independent features. It should be extended by 
overriding in a subclass.

=item _binary_features 

It returns a hash of binary features that combine both the anaphor and the
antecedent candidate.

Contains just language-independent features. It should be extended by 
overriding in a subclass.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

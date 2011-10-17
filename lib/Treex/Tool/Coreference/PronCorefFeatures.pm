package Treex::Tool::Coreference::PronCorefFeatures;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);


my $b_true = '1';
my $b_false = '-1';

my %actants = map { $_ => 1 } qw/ACT PAT ADDR APP/;
my %actants2 = map { $_ => 1 } qw/ACT PAT ADDR EFF ORIG/;

has 'cnk_freqs_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 
        'data/models/coreference/CS/features/cnk_nv_freq.txt',
);

has 'ewn_classes_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 
        'data/models/coreference/CS/features/noun_to_ewn_top_ontology.tsv',
);

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    lazy        => 1,
    builder     => '_build_feature_names',
);

has '_cnk_freqs' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef',
    lazy        => 1,
    builder     => '_build_cnk_freqs',
);

has '_ewn_classes' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef',
    lazy        => 1,
    builder     => '_build_ewn_classes',
);

has '_collocations' => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[Str]]'
);

has '_np_freq' => (
    is      => 'rw',
    isa     => 'HashRef[Int]'
);

# Attributes _cnk_freqs and _ewn_classes depend on attributes cnk_freqs_path
# and ewn_classes_path, whose values do not have to be accessible when
# building other attributes. Thus, _cnk_freqs and _ewn_classes are defined as
# lazy, i.e. they are built during their first access. However, we wish all
# models to be loaded while initializing a block. Following hack ensures it.
# For an analogous reason feature_names are accessed here as well. 
sub BUILD {
    my ($self) = @_;

    $self->_cnk_freqs;
    $self->_ewn_classes;
    $self->_build_feature_names;
}

sub _build_feature_names {
    my ($self) = @_;

    my @feat_names = qw(
       c_sent_dist        c_clause_dist         c_file_deepord_dist
       c_cand_ord
       
       c_cand_fun         c_anaph_fun           b_fun_agree               c_join_fun
       c_cand_afun        c_anaph_afun          b_afun_agree              c_join_afun
       b_cand_akt         b_anaph_akt           b_akt_agree 
       b_cand_subj        b_anaph_subj          b_subj_agree
       
       c_cand_gen         c_anaph_gen           b_gen_agree               c_join_gen
       c_cand_num         c_anaph_num           b_num_agree               c_join_num
       c_cand_apos        c_anaph_apos                                    c_join_apos
       c_cand_asubpos     c_anaph_asubpos                                 c_join_asubpos
       c_cand_agen        c_anaph_agen                                    c_join_agen
       c_cand_anum        c_anaph_anum                                    c_join_anum
       c_cand_acase       c_anaph_acase                                   c_join_acase
       c_cand_apossgen    c_anaph_apossgen                                c_join_apossgen
       c_cand_apossnum    c_anaph_apossnum                                c_join_apossnum
       c_cand_apers       c_anaph_apers                                   c_join_apers
       
       b_cand_coord       b_app_in_coord
       c_cand_epar_fun    c_anaph_epar_fun      b_epar_fun_agree          c_join_epar_fun
       c_cand_epar_sempos c_anaph_epar_sempos   b_epar_sempos_agree       c_join_epar_sempos
                                                b_epar_lemma_agree        c_join_epar_lemma
                                                                          c_join_clemma_aeparlemma
       c_cand_tfa         c_anaph_tfa           b_tfa_agree               c_join_tfa
       b_sibl             b_coll                r_cnk_coll
       r_cand_freq                            
       b_cand_pers

    );
    
    my ($noun_c, $all_c) = map {$self->_ewn_classes->{$_}} qw/noun all/;
    foreach my $class (sort @{$all_c}) {
        my $coref_class = "b_" . $class;
        push @feat_names, $coref_class;
    }
    return \@feat_names;
}

sub _build_cnk_freqs {
    my ($self) = @_;
    
    my $cnk_file = require_file_from_share( $self->cnk_freqs_path, ref($self) );
    log_fatal 'File ' . $cnk_file . 
        ' with a CNK model used for a feature' .
        ' in pronominal textual coreference resolution does not exist.' 
        if !-f $cnk_file;
# TODO adjustment to accord with Linh et al. (2009)
open CNK, $cnk_file;
#    open CNK, "<:utf8", $cnk_file;
    
    my $nv_freq;
    my $v_freq;
    
    while (my $line = <CNK>) {
        chomp $line;
        next if ($line =~ /^být/);  # slovesa modální - muset, chtít, moci, směti, mít
        my ($verb, $noun, $freq)= split "\t", $line;
        next if ($freq < 2);

        $v_freq->{$verb} += $freq;
        $nv_freq->{$noun}{$verb} = $freq;
    }
    close CNK;
    
    my $cnk_freqs = { v => $v_freq, nv => $nv_freq };
    return $cnk_freqs;
}

sub _build_ewn_classes {
    my ($self) = @_;

    my $ewn_file = require_file_from_share( $self->ewn_classes_path, ref($self) );
    log_fatal 'File ' . $ewn_file . 
        ' with a EuroWordNet onthology for Czech used' .
        ' in pronominal textual coreference resolution does not exist.' 
        if !-f $ewn_file;
# TODO adjustment to accord with Linh et al. (2009)
open EWN, $ewn_file;
#    open EWN, "<:utf8", $ewn_file;
    
    my $ewn_noun;
    my %ewn_all_classes;
    while (my $line = <EWN>) {
        chomp $line;
        
        my ($noun, $classes_string) = split /\t/, $line;
        my (@classes) = split / /, $classes_string;
        for my $class (@classes) {
            $ewn_noun->{$noun}{$class} = 1;
            $ewn_all_classes{$class} = 1;
        }
    }
    close EWN;

    my @class_list = keys %ewn_all_classes;
    my $ewn_classes = { nouns => $ewn_noun, all => \@class_list };

    return $ewn_classes;
}

# quantization
# takes an array of numbers, which corresponds to the boundary values of
# clusters
sub _categorize {
    my ( $real, $bins_rf ) = @_;
    my $retval = "-inf";
    for (@$bins_rf) {
        $retval = $_ if $real >= $_;
    }
    return $retval;
}

### returns the final gender and number of a list of coordinated nodes: Tata a mama sli; Mama a dite sly
sub _get_coord_gennum {
	my ($parray, $node) = @_;
	my $antec = ($node->get_coref_gram_nodes)[0];

    my ($gen, $num);

	if ((scalar @{$parray} == 1) || ($antec->functor eq 'APPS')) {
		$gen = $parray->[0]->gram_gender;
		$num = $parray->[0]->gram_number;
	}
	else {
		$num = 'pl';
		my %gens = (anim => 0, inan => 0, fem => 0, neut => 0);
		foreach (@{$parray}) {
			$gens{$_->gram_gender}++;
		}
		if ($gens{'anim'}) {
			$gen = 'anim';
		}
		elsif (($gens{'fem'} == scalar @{$parray}) || 
            ($gens{'fem'} && $gens{'neut'})) {
			$gen = 'fem';
		}
		elsif ($gens{'neut'} == scalar @{$parray}) {
			$gen = 'neut';
		}
		else  {
			$gen = 'inan';
		}
	}
	return ($gen, $num);
}

# returns the gender and number of the candidate, which is relative, according to his antecedent's gender and number
sub _get_relat_gennum {
	my ($node) = @_;
	my @epars = $node->get_eparents;
	my $par = $epars[0];
	while ($par && !(defined $par->gram_sempos && ($par->gram_sempos eq "v") 
        && defined $par->gram_tense && ($par->gram_tense =~ /^(sim|post|ant)$/))) {
		
        @epars = $par->get_eparents;
		$par = $epars[0];
	}
	my @antecs = $par->get_eparents;
	return _get_coord_gennum(\@antecs, $node);
}

### returns the gender and number of the candidate, which is reflexive, according to his antecedent's gender and number
sub _get_refl_gennum {
	my ($node) = @_;
	my $antec = ($node->get_coref_gram_nodes)[0];
	while ((!$antec->gram_gender || ($antec->gram_gender eq 'inher')) &&
        ($antec->attr('coref_gram.rf') || $antec->attr('coref_text.rf'))) {
		$antec = ($antec->get_coref_nodes)[0];
	}
	return ($antec->gram_gender, $antec->gram_number);
}

### returns the gender and number of the candidate, if cand = relative => get_relat_gennum(cand), if cand = refl => get_refl_gennum(cand)
sub _get_cand_gennum {
	my ($node) = @_;
	if ($node->attr('coref_gram.rf')) {
		if (defined $node->gram_indeftype && 
                ($node->gram_indeftype eq 'relat')) {


#			my $alex = $node->attr('a/lex.rf');
			my $anode = $node->get_lex_anode;
			my $alemma = $anode->lemma;
	
			if ($alemma !~ /^což/) {
				return _get_relat_gennum($node);
			}
		}
		elsif (($node->t_lemma eq '#PersPron') 
            && ($node->gram_person eq 'inher')) {
			return _get_refl_gennum($node);
		}
	}
	return ($node->gram_gender, $node->gram_number);
}

# returns the symbol in the $position of analytical node's tag of $node
sub _get_atag {
	my ($node, $position) = @_;
	my $anode = $node->get_lex_anode;
    if ($anode) {
		return substr($anode->tag, $position, 1);
	}
    return;
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

# TODO to accord with Linh et al. (2009), just the last subjects counts
        my $sb_id = pop @sb_ids;
        
        if ((!defined $sb_id && ($node->functor eq 'ACT'))
		    || (defined $sb_id && ($node->id eq $sb_id))) { 
			return $b_true;
		}	
        #if ((@sb_ids == 0) && ($node->functor eq 'ACT')) {
		#	return $b_true;
        #}
        #my %subj_hash = map {$_ => 1} @sb_ids; 
		#if (defined $subj_hash{$node->id}) { 
		#	return $b_true;
		#}	
	}
	return $b_false;
}

# returns whether an anaphor is APP and is in the same clause with a
# candidate and they have a common (grand)parent CONJ|DISJ
sub _is_app_in_coord {
	my ($cand, $anaph) = @_;
	if ($anaph->functor eq 'APP' && 
        ($anaph->wild->{aca_clausenum} eq $cand->wild->{aca_clausenum})) {
		
        my $par = $anaph->parent;
		while ($par && ($par != $cand) && 
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

# returns the first eparent's functor, sempos and lemma
sub _get_eparent_features {
	my ($node) = @_;
	my $epar_fun;
	my $epar_sempos;
	my $epar_lemma;
	my $epar = ($node->get_eparents)[0];
	if ($epar) {
		$epar_fun = $epar->functor;
		$epar_sempos = $epar->gram_sempos;
		$epar_lemma = $epar->t_lemma;
	}
	return ($epar_fun, $epar_sempos, $epar_lemma);
}

# returns if $inode and $jnode have the same eparent
sub _are_siblings {
	my ($inode, $jnode) = @_;
	my $ipar = ($inode->get_eparents)[0];
	my $jpar = ($jnode->get_eparents)[0];
	return ($ipar == $jpar) ? $b_true : $b_false;
}

# return if $inode and $jnode have the same collocation
sub _in_collocation {
	my ($self, $inode, $jnode) = @_;
    my $collocation = $self->_collocations;
	foreach my $jpar ($jnode->get_eparents) {
		if ($jpar->gram_sempos && ($jpar->gram_sempos =~ /^v/) && !$jpar->is_generated) {
			my $jcoll = $jnode->functor . "-" . $jpar->t_lemma;
			my $coll_list = $collocation->{$jcoll};
			if (() = grep {$_ eq $inode->t_lemma} @{$coll_list}) {
				return $b_true;
			}
		}
	}
	return $b_false;
}

# return if $inode and $jnode have the same collocation in CNK corpus
sub _in_cnk_collocation {
    my ($self, $inode, $jnode) = @_;
    foreach my $jpar ($jnode->get_eparents) {
        if ($jpar->gram_sempos && ($jpar->gram_sempos =~ /^v/) && !$jpar->is_generated) {
            my ($v_freq, $nv_freq) = map {$self->_cnk_freqs->{$_}} qw/v nv/;

            my $nv_sum = $nv_freq->{$inode->t_lemma}{$jpar->t_lemma};
            my $v_sum = $v_freq->{$jpar->t_lemma};
            if ($v_sum && $nv_sum) {
                return $nv_sum / $v_sum;
            }
        }
    }
    return 0;
}

sub join_feats {
    my ($f1, $f2) = @_;

# TODO adjustment to accord with Linh et al. (2009)
    if (!defined $f1) {
        $f1 = "";
    }
    if (!defined $f2) {
        $f2 = "";
    }

#    if (!defined $f1 || !defined $f2) {
#        return undef;
#    }
    return $f1 . '_' . $f2;
}

sub agree_feats {
    my ($f1, $f2) = @_;

# TODO adjustment to accord with Linh et al. (2009)
    if (!defined $f1 || !defined $f2) {
        if (!defined $f1 && !defined $f2) {
            return $b_true;
        }
        else {
            return $b_false;
        }
    }

#    if (!defined $f1 || !defined $f2) {
#        return $b_false;
#    }

    return ($f1 eq $f2) ? $b_true : $b_false;
}

### 18: gets anaphor's and antecedent-candidate' features (unary) and coreference features (binary)
sub extract_features {
    my ( $self, $cand, $anaph, $candord ) = @_;
    my %coref_features = ();
    
    #   1: anaphor's ID
    $coref_features{anaph_id} = $anaph->id;
    $coref_features{cand_id} = $cand->id;

###########################
    #   Distance:
    #   4x num: sentence distance, clause distance, file deepord distance, candidate's order
    $coref_features{c_sent_dist} =
        $anaph->get_bundle->get_position - $cand->get_bundle->get_position;
    $coref_features{c_clause_dist} = _categorize(
        $anaph->wild->{aca_clausenum} - $cand->wild->{aca_clausenum}, 
        [-2, -1, 0, 1, 2, 3, 7]
    );
    $coref_features{c_file_deepord_dist} = _categorize(
        $anaph->wild->{doc_ord} - $cand->wild->{doc_ord},
        [1, 2, 3, 6, 15, 25, 40, 50]
    );
    $coref_features{c_cand_ord} = _categorize(
        $candord,
        [1, 2, 3, 5, 8, 11, 17, 22]
    );

###########################
    #   Morphological:
    #   8:  gender, num, agreement, joined

    #TODO: REFACTOR this
    ( $coref_features{c_cand_gen}, $coref_features{c_cand_num} ) = _get_cand_gennum( $cand );

    $coref_features{c_anaph_gen} = $anaph->gram_gender;
    $coref_features{c_anaph_num} = $anaph->gram_number;

    $coref_features{b_gen_agree} 
        = agree_feats($coref_features{c_cand_gen}, $coref_features{c_anaph_gen});
    $coref_features{c_join_gen} 
        = join_feats($coref_features{c_cand_gen}, $coref_features{c_anaph_gen});

    $coref_features{b_num_agree} 
        = agree_feats($coref_features{c_cand_num}, $coref_features{c_anaph_num});
    $coref_features{c_join_num} 
        = join_feats($coref_features{c_cand_num}, $coref_features{c_anaph_num});

    #   24: 8 x tag($inode, $jnode), joined
    $coref_features{c_cand_apos}  = _get_atag( $cand,  0 );
    $coref_features{c_anaph_apos} = _get_atag( $anaph, 0 );
    $coref_features{c_join_apos}  
        = join_feats($coref_features{c_cand_apos}, $coref_features{c_anaph_apos});

    $coref_features{c_cand_asubpos}  = _get_atag( $cand,  1 );
    $coref_features{c_anaph_asubpos} = _get_atag( $anaph, 1 );
    $coref_features{c_join_asubpos}  
        = join_feats($coref_features{c_cand_asubpos}, $coref_features{c_anaph_asubpos});

    $coref_features{c_cand_agen}  = _get_atag( $cand,  2 );
    $coref_features{c_anaph_agen} = _get_atag( $anaph, 2 );
    $coref_features{c_join_agen}  
        = join_feats($coref_features{c_cand_agen}, $coref_features{c_anaph_agen});

    $coref_features{c_cand_anum}  = _get_atag( $cand,  3 );
    $coref_features{c_anaph_anum} = _get_atag( $anaph, 3 );
    $coref_features{c_join_anum}  
        = join_feats($coref_features{c_cand_anum}, $coref_features{c_anaph_anum});

    $coref_features{c_cand_acase}  = _get_atag( $cand,  4 );
    $coref_features{c_anaph_acase} = _get_atag( $anaph, 4 );
    $coref_features{c_join_acase}  
        = join_feats($coref_features{c_cand_acase}, $coref_features{c_anaph_acase});

    $coref_features{c_cand_apossgen}  = _get_atag( $cand,  5 );
    $coref_features{c_anaph_apossgen} = _get_atag( $anaph, 5 );
    $coref_features{c_join_apossgen}  
        = join_feats($coref_features{c_cand_apossgen}, $coref_features{c_anaph_apossgen});

    $coref_features{c_cand_apossnum}  = _get_atag( $cand,  6 );
    $coref_features{c_anaph_apossnum} = _get_atag( $anaph, 6 );
    $coref_features{c_join_apossnum}  
        = join_feats($coref_features{c_cand_apossnum}, $coref_features{c_anaph_apossnum});

    $coref_features{c_cand_apers}  = _get_atag( $cand,  7 );
    $coref_features{c_anaph_apers} = _get_atag( $anaph, 7 );
    $coref_features{c_join_apers}  
        = join_feats($coref_features{c_cand_apers}, $coref_features{c_anaph_apers});

###########################
    #   Functional:
    #   3:  functor($inode, $jnode);
    $coref_features{c_cand_fun}  = $cand->functor;
    $coref_features{c_anaph_fun} = $anaph->functor;
    $coref_features{b_fun_agree} 
        = agree_feats($coref_features{c_cand_fun}, $coref_features{c_anaph_fun});
    $coref_features{c_join_fun}  
        = join_feats($coref_features{c_cand_fun}, $coref_features{c_anaph_fun});

    #   3: afun($inode, $jnode);
    $coref_features{c_cand_afun}  = _get_afun($cand);
    $coref_features{c_anaph_afun} = _get_afun($anaph);

    # DEBUG
    #if (!defined $coref_features{c_cand_afun} || !defined $coref_features{c_anaph_afun}) {
    #    print STDERR "UNDEFINED: " . $anaph->{id} . ", " . $cand->{id} . "\n";
    #}

    $coref_features{b_afun_agree} 
        = agree_feats($coref_features{c_cand_afun}, $coref_features{c_anaph_afun});
    $coref_features{c_join_afun}  
        = join_feats($coref_features{c_cand_afun}, $coref_features{c_anaph_afun});

    #   3: aktant($inode, $jnode);
    $coref_features{b_cand_akt}  = $actants{ $cand->functor  } ? $b_true : $b_false;
    $coref_features{b_anaph_akt} = $actants{ $anaph->functor } ? $b_true : $b_false;
    $coref_features{b_akt_agree} 
        = agree_feats($coref_features{b_cand_akt}, $coref_features{b_anaph_akt});

    #   3:  subject($inode, $jnode);
    $coref_features{b_cand_subj}  = _is_subject($cand);
    $coref_features{b_anaph_subj} = _is_subject($anaph);
    $coref_features{b_subj_agree} 
        = agree_feats($coref_features{b_cand_subj}, $coref_features{b_anaph_subj});

###########################
    #   Context:
    $coref_features{b_cand_coord} = ( $cand->is_member ) ? $b_true : $b_false;
    # DEBUG ? $b_true : $b_false added
    $coref_features{b_app_in_coord} = _is_app_in_coord( $cand, $anaph ) ? $b_true : $b_false;

    #   4: get candidate and anaphor eparent functor and sempos
    #   2: agreement in eparent functor and sempos
    my $cand_epar_lemma;
    my $anaph_epar_lemma;
    ( $coref_features{c_cand_epar_fun},  $coref_features{c_cand_epar_sempos},  $cand_epar_lemma )  = _get_eparent_features($cand);
    ( $coref_features{c_anaph_epar_fun}, $coref_features{c_anaph_epar_sempos}, $anaph_epar_lemma ) = _get_eparent_features($anaph);
    $coref_features{b_epar_fun_agree}
        = agree_feats($coref_features{c_cand_epar_fun}, $coref_features{c_anaph_epar_fun});
    $coref_features{c_join_epar_fun}          
        = join_feats($coref_features{c_cand_epar_fun}, $coref_features{c_anaph_epar_fun});
    $coref_features{b_epar_sempos_agree}      
        = agree_feats($coref_features{c_cand_epar_sempos}, $coref_features{c_anaph_epar_sempos});
    $coref_features{c_join_epar_sempos}       
        = join_feats($coref_features{c_cand_epar_sempos}, $coref_features{c_anaph_epar_sempos});
    $coref_features{b_epar_lemma_agree}       
        = agree_feats($cand_epar_lemma, $anaph_epar_lemma);
    $coref_features{c_join_epar_lemma}        
        = join_feats($cand_epar_lemma, $anaph_epar_lemma);
    $coref_features{c_join_clemma_aeparlemma} 
        = join_feats($cand->t_lemma, $anaph_epar_lemma);

    #   3:  tfa($inode, $jnode);
    $coref_features{c_cand_tfa}  = $cand->tfa;
    $coref_features{c_anaph_tfa} = $anaph->tfa;
    $coref_features{b_tfa_agree} 
        = agree_feats($coref_features{c_cand_tfa}, $coref_features{c_anaph_tfa});
    $coref_features{c_join_tfa}  
        = join_feats($coref_features{c_cand_tfa}, $coref_features{c_anaph_tfa});

    #   1: are_siblings($inode, $jnode)
    # DEBUG ? $b_true : $b_false added
    $coref_features{b_sibl} = _are_siblings( $cand, $anaph ) ? $b_true : $b_false;

    #   1: collocation
    # DEBUG ? $b_true : $b_false added
    $coref_features{b_coll} = $self->_in_collocation( $cand, $anaph )  ? $b_true : $b_false;

    #   1: collocation from CNK
    $coref_features{r_cnk_coll} = $self->_in_cnk_collocation( $cand, $anaph );

    #   1:  freq($inode);
    #    $coref_features{cand_freq} = ($$np_freq{$cand->{t_lemma}} > 1) ? $b_true : $b_false;
    $coref_features{r_cand_freq} = $self->_np_freq->{ $cand->t_lemma } || 0;

###########################
    #   Semantic:
    #   1:  is_name_of_person
    $coref_features{b_cand_pers} =  $cand->is_name_of_person ? $b_true : $b_false;

    #   EuroWordNet nouns
    my $cand_lemma      = $cand->t_lemma;
    my ($noun_c, $all_c) = map {$self->_ewn_classes->{$_}} qw/nouns all/;
    my $cand_c = $noun_c->{$cand_lemma};
    
    for my $class ( @{$all_c} ) {
        my $coref_class = "b_" . $class;
        $coref_features{$coref_class} = defined $cand_c->{$class} ? $b_true : $b_false;
    }

# DEBUG
#    if (($anaph->id eq 't-cmpr9410-047-p15s2a1') && ($coref_features{b_Creature} == $b_true)) {
#        print STDERR $cand->t_lemma . "\n";
#    }
    
    #   celkem 71 vlastnosti + ID
    return ( \%coref_features );
}

sub count_collocations {
    my ( $self, $trees ) = @_;
    my ( $collocation ) = {};
    
    foreach my $tree (@{$trees}) {
        foreach my $node ( $tree->descendants ) {

            if ($node->gram_sempos && ( $node->gram_sempos =~ /^v/ ) && !$node->is_generated ) {
                
                foreach my $child ( $node->get_echildren ) {
                    
                    if ( $child->functor && $actants2{ $child->functor } && 
                        $child->gram_sempos && ( $child->gram_sempos =~ /^n\.denot/ )) {
                        
                        my $key = $child->functor . "-" . $node->t_lemma;
                        push @{ $collocation->{$key} }, $child->t_lemma;
                    }
                }
            }
        }
    }
    $self->_set_collocations( $collocation );
}

sub count_np_freq {
    my ( $self, $trees ) = @_;
    my $np_freq  = {};

    foreach my $tree (@{$trees}) {
        foreach my $node ( $tree->descendants ) {
            
            if ($node->gram_sempos && ($node->gram_sempos =~ /^n\.denot/ ) 
                && (!$node->gram_person || ( $node->gram_person !~ /1|2/ ))) {
                    
                    $np_freq->{ $node->t_lemma }++;
            }
        }
    }
    $self->_set_np_freq( $np_freq );
}

sub mark_doc_clause_nums {
    my ($self, $trees) = @_;

    my $curr_clause_num = 0;
    foreach my $tree (@{$trees}) {
        my $clause_count = 0;
        
        foreach my $node ($tree->descendants ) {
            # TODO clause_number returns 0 for coap

            $node->wild->{aca_clausenum} = 
                $node->clause_number + $curr_clause_num;
            if ($node->clause_number > $clause_count) {
                $clause_count = $node->clause_number;
            }
        }
        $curr_clause_num += $clause_count;
    }
}

1;

# Copyright 2008-2011 Nguy Giang Linh, Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Tool::Coreference::PronCorefFeatures

use Treex::Core::Common

my $b_true = '1';
my $b_false = '-1';

my %actants = map { $_ => 1 } qw/ACT PAT ADDR APP/;
my %actants2 = map { $_ => 1 } qw/ACT PAT ADDR EFF ORIG/;

# Bere cislo a odkaz na seznam hranic skatulek. Soupne cislo tak, aby cisla mezi dvema hranicemi
# dostala stejnou hodnotu
sub categorize {
    my ( $real, $bins_rf ) = @_;
    my $retval = "-inf";
    for (@$bins_rf) {
        $retval = $_ if $real >= $_;
    }
    return $retval;
}

### marks clausenum with the finite verb's clausenum
sub mark_clause {
    my ( $node, $clausenum, $p_vlist ) = @_;
    if ( $node->{nodetype} eq "coap" ) {
        foreach my $child ( $node->children ) {
            if ( grep { $_ eq $child } @$p_vlist ) {
                $clausenum = ( $child->{aca_clausenum} < $clausenum ) ? $child->{aca_clausenum} : $clausenum;

                #		 		$clausenum = ($child->{aca_clausenum} > $clausenum) ? $child->{aca_clausenum} : $clausenum;
            }
        }
    }
    elsif ( grep { $_ eq $node } @$p_vlist ) {
        $clausenum = $node->{aca_clausenum};
    }
    $node->{aca_clausenum} = $clausenum;
    foreach my $child ( $node->children ) {
        mark_clause( $child, $clausenum, $p_vlist );
    }
}

### looks for finite verbs, sorts them by deepord and marks their clausenum with their ord; returns the number of finite verbs
sub mark_clause_root($) {
    my ($node) = @_;
    my @vlist = grep { $_->attr('gram/tense') =~ /^(sim|ant|post)/ or $_->{functor} =~ /^(PRED|DENOM)$/ } $node->descendants;
    @vlist = sort { $a->{deepord} <=> $b->{deepord} } @vlist;
    my $id = 0;
    foreach my $verb (@vlist) {
        $verb->{aca_clausenum} = $id;
        $id++;

        #		print "$verb->{t_lemma}:$verb->{aca_clausenum}\n";
    }
    mark_clause( $node, 0, \@vlist );
    return $#vlist + 1;
}


sub count_collocations {
    my ( $trees ) = @_;
    my ( $collocation );
    
    foreach my $tree (@{$trees}) {
        foreach my $node ( $tree->descendants ) {
            
            if (( $node->gram_sempos =~ /^v/ ) && !$node->is_generated ) {
                
                foreach my $child ( $node->get_echildren ) {
                    
                    if ( $actants2{ $child->functor } && 
                        ( $child->gram_sempos =~ /^n\.denot/ )) {
                        
                        my $key = $child->functor . "-" . $node->t_lemma;
                        push @{ $collocation->{$key} }, $child->t_lemma;
                    }
                }
            }

        }
    }

    return ( $collocation );
}

sub count_np_freq {
    my ( $trees ) = @_;
    my ( $np_freq );
    
    foreach my $tree (@{$trees}) {
        foreach my $node ( $tree->descendants ) {
            
            if (($node->gram_sempos =~ /^n\.denot/ ) 
                && ( $node->gram_person !~ /1|2/ )) {
                    
                    $np_freq->{ $node->t_lemma }++;
            }

        }
    }

    return ( $np_freq );
}

sub mark_clause_nums {
 # TODO
}

sub mark_sentence_nums {
    my ( $trees ) = @_;
    my $sentnum = 1;
    
    foreach my $tree (@{$trees}) {
        foreach my $node ( $tree->descendants ) {
            
            $node->wild->{aca_sentnum} = $sentnum;
        }
        $sentnum++;
    }
}


# REFACTORED
# TODO consider renaming or splitting into several methods
# gets the list of all noun phrases, the list of all anaphors in the file, noun-phrase frequencies and the collocation list
sub analyze_file {
    my $file_clause_num = 0;

    foreach my $tree (@trees) {
        # TODO clause numbers using Node::InClause
        my $clause_num = mark_clause_root($tree);

        foreach my $node ( $tree->descendants ) {
            $node->wild->{aca_clausenum} =
                $node->wild->{aca_clausenum} + $file_clause_num;
        }

        $file_clause_num += $clause_num;
    }

    # TODO deepord
    my $nodeord = 0;
    foreach my $node (@all_nodes) {
        $node->wild->{aca_file_deepord} = $nodeord++;
    }

    return ( $all_nps, $all_anaphs, $np_freq, $collocation );
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
    return $b_false if (!defined $par);
	
    if (($par->gram_tense =~ /^(sim|ant|post)/) || 
        ($par->functor eq 'DENOM')) {
		
        my @cands = $par->get_echildren;
 		my $sb_id;
		foreach my $child (@cands) {
			if ($child->gram_sempos =~ /^n/) {
                my $achild = get_lex_anode($child);
                if (defined $achild && ($achild->afun eq 'Sb')) {
					$sb_id = $child->{id};
                    last;
				}
			}
		}
		if (($node->id eq $sb_id) || 
            (!defined $sb_id && ($node->functor eq 'ACT'))) {
			return $b_true;
		}	
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
            $par->gram_tense !~ /^(sim|ant|post)/ && 
            $par->functor !~ /^(PRED|DENOM)$/) {
			
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
#		$$coref_features{"$prefix\_epar\_fun"} = $par->{functor};
#		$$coref_features{"$prefix\_epar\_sempos"} = $par->attr('gram/sempos');
	}
	return ($epar_fun, $epar_sempos, $epar_lemma);
}

# returns if $inode and $jnode have the same eparent
sub _are_siblings {
	my ($inode, $jnode) = @_;
	my $ipar = ($inode->get_eparents)[0];
	my $jpar = ($jnode->get_eparents)[0];
	return ($ipar eq $jpar) ? $b_true : $b_false;
#	return agreement($ipar, $jpar);
}

# return if $inode and $jnode have the same collocation
sub _in_collocation {
	my ($inode, $jnode, $collocation) = @_;
	foreach my $jpar ($jnode->get_eparents) {
		if (($jpar->gram_sempos =~ /^v/) && !$jpar->is_generated) {
			my $jcoll = $jnode->functor . "-" . $jpar->t_lemma;
			my $coll_list = $collocation->{$jcoll};
			if (() = grep {$_ eq $inode->t_lemma} @{$coll_list}) {
				return $b_true;
			}
		}
	}
	return $b_false;
}

### 18: gets anaphor's and antecedent-candidate' features (unary) and coreference features (binary)
sub get_coref_features {
    my ( $cand, $anaph, $candord, $np_freq, $collocation ) = @_;
    my %coref_features = ();
    my @feat_names     = qw(
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

    #   1: anaphor's ID
    $coref_features{anaph_id} = $anaph->id;

###########################
    #   Distance:
    #   4x num: sentence distance, clause distance, file deepord distance, candidate's order
    $coref_features{c_sent_dist} =
        $anaph->wild->{aca_sentnum} - $cand->wild->{aca_sentnum};
    $coref_features{c_clause_dist} = categorize(
        $anaph->wild->{aca_clausenum} - $cand->wild->{aca_clausenum}, 
        [-2, -1, 0, 1, 2, 3, 7]
    );
    $coref_features{c_file_deepord_dist} = categorize(
        $anaph->wild->{aca_file_deepord} - $cand->wild->{aca_file_deepord},
        [1, 2, 3, 6, 15, 25, 40, 50]
    );
    $coref_features{c_cand_ord} = categorize(
        $candord,
        [1, 2, 3, 5, 8, 11, 17, 22]
    );

###########################
    #   Morphological:
    #   8:  gender, num, agreement, joined

    #TODO: REFACTOR this
    ( $coref_features{c_cand_gen}, $coref_features{c_cand_num} ) = get_cand_gennum($cand);

    $coref_features{c_anaph_gen} = $anaph->gram_gender;
    $coref_features{c_anaph_num} = $anaph->gram_number;

    $coref_features{b_gen_agree} = ( $coref_features{c_cand_gen} eq $coref_features{c_anaph_gen} )
        ? $b_true : $b_false;
    $coref_features{c_join_gen} = $coref_features{c_cand_gen} . "_" . $coref_features{c_anaph_gen};

    $coref_features{b_num_agree} = ( $coref_features{c_cand_num} eq $coref_features{c_anaph_num} )
        ? $b_true : $b_false;
    $coref_features{c_join_num} = $coref_features{c_cand_num} . "_" . $coref_features{c_anaph_num};

    #   24: 8 x tag($inode, $jnode), joined
    $coref_features{c_cand_apos}  = _get_atag( $cand,  0 );
    $coref_features{c_anaph_apos} = _get_atag( $anaph, 0 );
    $coref_features{c_join_apos}  = $coref_features{c_cand_apos} . "_" . $coref_features{c_anaph_apos};

    $coref_features{c_cand_asubpos}  = _get_atag( $cand,  1 );
    $coref_features{c_anaph_asubpos} = _get_atag( $anaph, 1 );
    $coref_features{c_join_asubpos}  = $coref_features{c_cand_asubpos} . "_" . $coref_features{c_anaph_asubpos};

    $coref_features{c_cand_agen}  = _get_atag( $cand,  2 );
    $coref_features{c_anaph_agen} = _get_atag( $anaph, 2 );
    $coref_features{c_join_agen}  = $coref_features{c_cand_agen} . "_" . $coref_features{c_anaph_agen};

    $coref_features{c_cand_anum}  = _get_atag( $cand,  3 );
    $coref_features{c_anaph_anum} = _get_atag( $anaph, 3 );
    $coref_features{c_join_anum}  = $coref_features{c_cand_anum} . "_" . $coref_features{c_anaph_anum};

    $coref_features{c_cand_acase}  = _get_atag( $cand,  4 );
    $coref_features{c_anaph_acase} = _get_atag( $anaph, 4 );
    $coref_features{c_join_acase}  = $coref_features{c_cand_acase} . "_" . $coref_features{c_anaph_acase};

    $coref_features{c_cand_apossgen}  = _get_atag( $cand,  5 );
    $coref_features{c_anaph_apossgen} = _get_atag( $anaph, 5 );
    $coref_features{c_join_apossgen}  = $coref_features{c_cand_apossgen} . "_" . $coref_features{c_anaph_apossgen};

    $coref_features{c_cand_apossnum}  = _get_atag( $cand,  6 );
    $coref_features{c_anaph_apossnum} = _get_atag( $anaph, 6 );
    $coref_features{c_join_apossnum}  = $coref_features{c_cand_apossnum} . "_" . $coref_features{c_anaph_apossnum};

    $coref_features{c_cand_apers}  = _get_atag( $cand,  7 );
    $coref_features{c_anaph_apers} = _get_atag( $anaph, 7 );
    $coref_features{c_join_apers}  = $coref_features{c_cand_apers} . "_" . $coref_features{c_anaph_apers};

###########################
    #   Functional:
    #   3:  functor($inode, $jnode);
    $coref_features{c_cand_fun}  = $cand->functor;
    $coref_features{c_anaph_fun} = $anaph->functor;
    $coref_features{b_fun_agree} = ( $coref_features{c_cand_fun} eq $coref_features{c_anaph_fun} ) ? $b_true : $b_false;
    $coref_features{c_join_fun}  = $coref_features{c_cand_fun} . "_" . $coref_features{c_anaph_fun};

    #   3: afun($inode, $jnode);
    $coref_features{c_cand_afun}  = _get_afun($cand);
    $coref_features{c_anaph_afun} = _get_afun($anaph);
    $coref_features{b_afun_agree} = ( $coref_features{c_cand_afun} eq $coref_features{c_anaph_afun} ) ? $b_true : $b_false;
    $coref_features{c_join_afun}  = $coref_features{c_cand_afun} . "_" . $coref_features{c_anaph_afun};

    #   3: aktant($inode, $jnode);
    $coref_features{b_cand_akt}  = $actants{ $cand->functor  } ? $b_true : $b_false;
    $coref_features{b_anaph_akt} = $actants{ $anaph->functor } ? $b_true : $b_false;
    $coref_features{b_akt_agree} = ( $coref_features{b_cand_akt} eq $coref_features{b_anaph_akt} ) ? $b_true : $b_false;

    #   3:  subject($inode, $jnode);
    $coref_features{b_cand_subj}  = _is_subject($cand);
    $coref_features{b_anaph_subj} = _is_subject($anaph);
    $coref_features{b_subj_agree} = ( $coref_features{b_cand_subj} eq $coref_features{b_anaph_subj} ) ? $b_true : $b_false;

###########################
    #   Context:
    $coref_features{b_cand_coord} = ( $cand->is_member ) ? $b_true : $b_false;
    $coref_features{b_app_in_coord} = _is_app_in_coord( $cand, $anaph ) ? $b_true : $b_false;

    #   4: get candidate and anaphor eparent functor and sempos
    #   2: agreement in eparent functor and sempos
    my $cand_epar_lemma;
    my $anaph_epar_lemma;
    ( $coref_features{c_cand_epar_fun},  $coref_features{c_cand_epar_sempos},  $cand_epar_lemma )  = _get_eparent_features($cand);
    ( $coref_features{c_anaph_epar_fun}, $coref_features{c_anaph_epar_sempos}, $anaph_epar_lemma ) = _get_eparent_features($anaph);
    $coref_features{b_epar_fun_agree}         = ( $coref_features{c_cand_epar_fun} eq $coref_features{c_anaph_epar_fun} ) ? $b_true : $b_false;
    $coref_features{c_join_epar_fun}          = $coref_features{c_cand_epar_fun} . "_" . $coref_features{c_anaph_epar_fun};
    $coref_features{b_epar_sempos_agree}      = ( $coref_features{c_cand_epar_sempos} eq $coref_features{c_anaph_epar_sempos} ) ? $b_true : $b_false;
    $coref_features{c_join_epar_sempos}       = $coref_features{c_cand_epar_sempos} . "_" . $coref_features{c_anaph_epar_sempos};
    $coref_features{b_epar_lemma_agree}       = ( $cand_epar_lemma eq $anaph_epar_lemma ) ? $b_true : $b_false;
    $coref_features{c_join_epar_lemma}        = $cand_epar_lemma . "_" . $anaph_epar_lemma;
    $coref_features{c_join_clemma_aeparlemma} = $cand->{t_lemma} . "_" . $anaph_epar_lemma;

    #   3:  tfa($inode, $jnode);
    $coref_features{c_cand_tfa}  = $cand->tfa;
    $coref_features{c_anaph_tfa} = $anaph->tfa;
    $coref_features{b_tfa_agree} = ( $coref_features{c_cand_tfa} eq $coref_features{c_anaph_tfa} ) ? $b_true : $b_false;
    $coref_features{c_join_tfa}  = $coref_features{c_cand_tfa} . "_" . $coref_features{c_anaph_tfa};

    #   1: are_siblings($inode, $jnode)
    $coref_features{b_sibl} = _are_siblings( $cand, $anaph ) ? $b_true : $b_false;

    #   1: collocation
    $coref_features{b_coll} = _in_collocation( $cand, $anaph, $collocation ) ? $b_true : $b_false;

######### TODO CONTINUE IN REFACTORING HERE ##############


    #   1: collocation from CNK
    $coref_features{r_cnk_coll} = in_cnk_collocation( $cand, $anaph, $p_nv_freq, $p_v_freq );

    #   1:  freq($inode);
    #    $coref_features{cand_freq} = ($$np_freq{$cand->{t_lemma}} > 1) ? $b_true : $b_false;
    $coref_features{r_cand_freq} = $np_freq->{ $cand->{t_lemma} };

###########################
    #   Semantic:
    #   1:  is_name_of_person
    $coref_features{b_cand_pers} = ( $cand->{is_name_of_person} ) ? $b_true : $b_false;

    #   EuroWordNet nouns
    my $cand_lemma      = $cand->{t_lemma};
    my $p_cand_class    = $p_ewn_noun->{$cand_lemma};
    my @cand_class_list = keys %{$p_cand_class};
    if ( $#cand_class_list >= 0 ) {
        for my $class ( @{$p_ewn_classes} ) {
            my $coref_class = "b_" . $class;
            $coref_features{$coref_class} = ( grep { $_ eq $class } @cand_class_list ) ? $b_true : $b_false;
        }
    }
    else {
        for my $class ( @{$p_ewn_classes} ) {
            my $coref_class = "b_" . $class;
            $coref_features{$coref_class} = $b_false;
        }
    }
    for my $class ( @{$p_ewn_classes} ) {
        my $coref_class = "b_" . $class;
        push @feat_names, $coref_class;
    }

    #   celkem 71 vlastnosti + ID
    return ( \%coref_features, \@feat_names );
}
1;

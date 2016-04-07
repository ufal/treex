package Treex::Block::Eval::AddPersPronIt;
use Moose;
use utf8;
use Treex::Core::Common;
use Treex::Block::Eval::AddPersPronSb;
extends 'Treex::Core::Block';

my $anaph_path = 'it_anaph.ls';
my $non_anaph_path = 'it_non_anaph.ls';
my $pleon_path = 'it_pleon.ls';

my $anaph_path_cs = 'it_anaph_cs.ls';
my $non_anaph_path_cs = 'it_non_anaph_cs.ls';
my $pleon_path_cs = 'it_pleon_cs.ls';

my $impersonal_verbs = 'jednat_se|pršet|zdát_se|dařit_se|oteplovat_se|ochladit_se|stát_se|záležet';
my $modal_adjs = 'possible|clear|certain|definite|probable|important|imperative|necessary|useful|easy|hard';
my $to_clause_verbs = 'be|s|become|make|take';
my $to_clause_verbs_pat = 'make|take';
my $be_verbs = 'be|s|become';
my $cog_ed_verbs = 'think|believe|recommend|say|note|expect';
my $cog_verbs = 'seem|appear|mean|follow|matter';

my ($correct_sum, $eval_sum, $total_sum, $allcands_sum) = (0, 0 ,0);

my ($anaph_sum, $non_anaph_sum, $pleon_sum, $pleon_cs_sum, $pleon_en_sum, $segm_sum, $to_sum, $pp_sum) = (0, 0, 0, 0, 0, 0, 0, 0);

sub is_byt_videt {
    my ($t_node) = @_;
    my ($epar) = $t_node->get_eparents( { or_topological => 1 } ) if ( $t_node );
    return ( $t_node->t_lemma eq "být"
        and grep { $_->t_lemma =~ /^(vidět|slyšet|cítit)$/ } $t_node->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

sub has_o_ending {
    my ( $t_node ) = @_;
    return ( grep { $_->tag =~ /^V/ and $_->form =~ /o$/ } $t_node->get_anodes
    ) ? 1 : 0;
}

sub is_active_present_3_sg {
    my ( $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode;
    my @anodes = ($a_node, $t_node->get_aux_anodes);
    if ( $a_node ) {
        if ( $a_node->tag !~ /^Vs/ 
            and grep { $_->tag =~ /^V.......(P|F)/ } @anodes 
            and grep { $_->tag =~ /^V......3/ } @anodes 
            and grep { $_->tag =~ /^V..S/ } @anodes ) {
            return 1;
        }
    }
    return 0;
}

# MarkClauseHead
#     if ( $t_node->get_lex_anode && grep { $_->tag =~ /^V[Bpi]/ } $t_node->get_anodes ) {
#         $t_node->set_is_clause_head(1);
#     }

sub is_3_sg_neut {
    my ( $t_node ) = @_;
    return ( is_active_present_3_sg($t_node) or has_o_ending($t_node) 
    ) ? 1 : 0;
}

sub is_3_sg {
    my ( $t_node ) = @_;
#     my ( $t_node, $t_en_node ) = @_;
    my @anodes = $t_node->get_anodes;
    if ( @anodes > 0 ) {
        if ( grep { $_->tag =~ /^V/ } @anodes 
            and not grep { $_->tag =~ /^.......(1|2)/ } @anodes 
#             and grep { $_->tag =~ /^.......3/ } @anodes 
            and grep { $_->tag =~ /^...(S|W)/ } @anodes 
        ) {
            return 1;
        }
    }
#     if ( $t_en_node
#         and $t_en_node->get_lex_anode
#         and grep { $_->lemma =~ /^(he|she|it)$/
#             and $_->afun eq "Sb"
#         } $t_en_node->get_lex_anode->children
#     ) {
#         return 1;
#     }
    return 0;
}

# returns 1 if the given node is a reflexive passivum
sub is_refl_pass {
    my ($t_node) = @_;
    foreach my $anode ( $t_node->get_anodes ) {
        return 1 if ( grep { $_->afun eq "AuxR" and $_->form eq "se" } $anode->children );
    }
    return 0;
}

# returns 1 if the given node has an echild with #Gen as its subject
sub is_GEN {
    my ( $t_node ) = @_;
    return ( is_byt_videt($t_node)
        or has_o_ending($t_node)
        or (is_refl_pass($t_node) and is_active_present_3_sg($t_node))
    ) ? 1 : 0;
}

# # returns 1 if eg. jde o zivot - impersonal (It's about ...)
sub is_jit_o {
    my ( $t_node ) = @_;
    if ( $t_node->t_lemma eq "jít" ) {
        foreach my $echild ( grep { $_->functor eq "ACT" } $t_node->get_echildren ( { or_topological => 1 } ) ) {
            foreach my $anode ( $echild->get_anodes ) {
                return 1 if ( $anode->form eq "o" );
            }
        }
    }
    return 0;
}

# returns 1 if the given node is an impersonal verb
sub is_IMPERS {
    my ( $t_node ) = @_;
    return ( $t_node->t_lemma =~ /^($impersonal_verbs)$/ 
        or is_jit_o($t_node)
    ) ? 1 : 0;
}

# returns 1 if the node has a subject among t-children and a-children of all anodes; otherwise 0
sub has_asubject {
    my ( $t_node ) = @_;
    return 1 if ( grep { not $_->is_generated and $_->get_lex_anode->afun eq "Sb" } $t_node->get_echildren( { or_topological => 1 } ) );
#     foreach my $child ( grep { not $_->is_generated } $t_node->get_echildren( { or_topological => 1 } ) ) {
#         return 1 if ( $child->get_lex_anode->afun eq "Sb" );
#     }
    foreach my $averb ( grep { $_->tag =~ /^V/ } $t_node->get_anodes ) {
        return 1 if ( grep { $_->afun eq "Sb" } $averb->children );
        my ($acoord) = grep { $_->afun eq "Coord" } $averb->children;
        if ( $acoord ) {
            return 1 if ( grep { $_->afun eq "Sb" } $acoord->children );
        }
    }
    return 0;
}

# error in adding functor, the predicate of the subject subordinate clause has PAT functor
sub has_sb_clause {
    my ( $t_node ) = @_;
    return ( grep { $_->functor eq "PAT"
            and ($_->gram_sempos || "") eq "v"
            and not $_->is_generated
            and $_->get_lex_anode->tag =~ /^Vs/
        } $t_node->get_echildren ( { or_topological => 1 } )
    ) ? 1 : 0;
}

sub has_subject {
    my ( $t_node ) = @_;
    return ( grep { ( $_->formeme || "" ) eq "n:1" } $t_node->get_echildren( { or_topological => 1 } )
        or has_asubject($t_node)
        or has_sb_clause($t_node)
    ) ? 1 : 0;
}

sub analyze_en {
    my ( $en_tree ) = @_;

#     open(ANAPH, ">>:encoding(UTF-8)", $anaph_path) || die "Can't open $anaph_path: $!";
#     open(NON_ANAPH, ">>:encoding(UTF-8)", $non_anaph_path) || die "Can't open $non_anaph_path: $!";
#     open(PLEON, ">>:encoding(UTF-8)", $pleon_path) || die "Can't open $pleon_path: $!";
    
    foreach my $t_node ( $en_tree->get_descendants ) {
        my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_anodes;
        if ( $a_it ) {
#         if ( $a_it and $a_it->afun eq "Sb" ) {
            my $cs_node;
            if ( $t_node->get_lex_anode->lemma eq "it" ) {
                if ( $t_node->get_coref_nodes > 0 ) {
                    $anaph_sum++;
                    my @antecs = $t_node->get_coref_nodes;
                    if ( ($antecs[0]->gram_sempos || "") eq "v" ) {
                        $segm_sum++;
                    }
                }
                else {
                    $non_anaph_sum++;
                }
                my ($aligned, $types) = $t_node->get_directed_aligned_nodes;
                if ( $aligned and $types->[0] ne "monolingual" ) {
    #                     $cs_node = $aligned->[0];
    #                         $cs_node->t_lemma eq "ten" ) {
                    if ( grep { $_->t_lemma eq "ten" } @$aligned ) {
                        $to_sum++;
                    }
                    elsif ( grep { $_->t_lemma eq "#PersPron" } @$aligned ) {
                        $pp_sum++;
                    }
                }
            }
            else {
                $pleon_sum++;
                my ($aligned, $types) = $t_node->get_directed_aligned_nodes;
                if ( $aligned and $types->[0] ne "monolingual" ) {
                    $cs_node = $aligned->[0];
                    if ( Treex::Block::Eval::AddPersPronSb::has_pleon_sb($cs_node) ) {
                        $pleon_cs_sum++;
#                         print $cs_node->get_address . "\n";
                    }
                }
            }
        }
#         if ( grep { $_->lemma eq "it" } $t_node->get_lex_anode ) {
#             if ( $t_node->get_coref_nodes > 0 ) {
#                 $anaph_sum++;
#             }
#             else {
#                 $non_anaph_sum++;
#             }
#             if ( $t_node->t_lemma ne "#PersPron" ) {
#                 print PLEON $t_node->get_address . "\n";
#             }
#             elsif ( $t_node->get_coref_nodes > 0 ) {
#                 print ANAPH $t_node->get_address . "\n";
#             }
#             else {
#                 print NON_ANAPH $t_node->get_address . "\n";
#             }
#         }
#         elsif ( grep { $_->lemma eq "it" } $t_node->get_aux_anodes ) {
#             
#         }
    }

#     close(ANAPH);
#     close(NON_ANAPH);
#     close(PLEON);
#     print join "\t", ($anaph_sum, $non_anaph_sum, $pleon_sum, $pleon_cs_sum, $segm_sum, $to_sum, $pp_sum);
#     print "\n";
}

sub en_has_ACT {
    my ($verb, $t_node, $it) = @_;
    return (
        ($verb->gram_sempos || "") eq "v"
        and $verb->get_lex_anode and $verb->get_lex_anode->tag ne "VBN"
#         $verb->get_lex_anode and $verb->get_lex_anode->tag =~ /^V/
        and grep { $_->functor eq "ACT"
            and $_ ne $t_node
            and not $_->is_generated
            and ($_->gram_sempos || "") eq "v"
        } $verb->get_echildren( { or_topological => 1} )
        and $it->afun eq "Sb"
    ) ? 1 : 0;
}

sub en_has_PAT {
    my ($verb, $t_node, $it) = @_;
    return (
        $verb->get_lex_anode and $verb->get_lex_anode->tag eq "VBN"
        and grep { $_->functor eq "PAT"
            and $_ ne $t_node
            and not $_->is_generated
            and ($_->gram_sempos || "") eq "v"
        } $verb->get_echildren( { or_topological => 1} )
        and $it->afun eq "Sb"
    ) ? 1 : 0;
}

sub make_it_to {
    my ($verb, $t_node) = @_;
    return (
        $verb->t_lemma eq "make"
        and grep { $_->functor eq "PAT"
            and $_ ne $t_node
            and not $_->is_generated
        } $verb->get_echildren( { or_topological => 1} )
    ) ? 1 : 0;
}

# returns 1 if the given node is a passive verb
sub is_passive {
    my ($t_node) = @_;
    return (  grep { $_->tag =~ /^Vs/ } $t_node->get_anodes
        or is_refl_pass($t_node)
    ) ? 1 : 0;
}

# returns 1 if the given node is an passive verb and has an echild with PAT => possibly has an overt subject
# PAT can be an expressed word or a #PersPron drop
sub is_passive_having_PAT {
    my ( $t_node ) = @_;
    return ( is_passive($t_node)
        and grep { ($_->functor || "" ) eq "PAT" 
            and ( not $_->is_generated or $_->t_lemma eq "#EmpNoun" )
#             and ( not $_->is_generated or $_->t_lemma eq "#PersPron" ) } $t_node->get_echildren( { or_topological => 1 } ) 
        } $t_node->get_echildren( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

# returns 1 if the given node is an active verb and has an echild with ACT => possibly has an overt subject
# ACT can be an expressed word or a #PersPron drop
sub is_active_having_ACT {
    my ( $t_node ) = @_;
    return ( 
        not is_passive($t_node)
        and grep { ($_->functor || "" ) eq "ACT" 
            and ( not $_->is_generated or $_->t_lemma eq "#EmpNoun" )
#             and not ( $_->is_generated and $_->t_lemma eq "#PersPron" )
        } $t_node->get_echildren( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

sub analyze_cs {
    my ( $cs_tree, $en_tree ) = @_;

#     open(ANAPH_CS, ">>:encoding(UTF-8)", $anaph_path_cs) || die "Can't open $anaph_path_cs: $!";
#     open(NON_ANAPH_CS, ">>:encoding(UTF-8)", $non_anaph_path_cs) || die "Can't open $non_anaph_path_cs: $!";
#     open(PLEON_CS, ">>:encoding(UTF-8)", $pleon_path_cs) || die "Can't open $pleon_path_cs: $!";
    my %cs2en_node = get_cs2en_links($en_tree);
    foreach my $cand_verb (
        grep { 
            ($_->gram_sempos || "") eq "v"
            and is_3_sg($_)
#             and is_3_sg($_, $cs2en_node{$_})
#             and is_3_sg_neut($_)
            and not $_->is_generated
        } $cs_tree->get_descendants
    ) {
#         $to_sum++;
#         if ( $cand_verb->id eq "T-wsj0041-001-p1s20a1" ) {
# #             print "a tady\n";
#             if ( Treex::Block::Eval::AddPersPronSb::has_pleon_sb($cand_verb) ) {
# #                 print "tady jsme\n";
#             }
#         }
        my $en_verb = $cs2en_node{$cand_verb};
        if ( Treex::Block::Eval::AddPersPronSb::has_pleon_sb($cand_verb) ) {
#             print $cand_verb->get_address . "\n";
            $pleon_sum++;
            if ( $en_verb and grep { $_->lemma eq "it" } $en_verb->get_aux_anodes ) {
                $pleon_en_sum++;
            }
        }
        elsif ( Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($cand_verb) ) {
#             print $cand_verb->get_address . "\n";
            my $perspron;
            my @echildren = $cand_verb->get_echildren( { or_topological => 1 } );
            if ( is_passive($cand_verb) ) {
                ($perspron) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated and $_->functor eq "PAT" } @echildren;
            }
            else {
                ($perspron) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated and $_->functor eq "ACT" } @echildren;
            }
            if ( $perspron and $perspron->get_coref_nodes > 0 ) {
                $anaph_sum++;
                my @antecs = $perspron->get_coref_nodes;
                if ( grep { ($_->gram_sempos || "") eq "v" } @antecs ) {
                    $segm_sum++;
                }
            }
            elsif ( $perspron ){
                $non_anaph_sum++;
            }
#             if ( $en_verb and grep { $_->lemma eq "it" } $en_verb->get_aux_anodes ) {
#                 $pleon_en_sum++;
#             }
        }
        else {
#             print $cand_verb->get_address . "\n";
        }
#         if ( Treex::Block::Eval::AddPersPronSb::has_pleon_sb($cand_verb) ) {
#             $pleon_sum++;
#             print $cand_verb->get_address . "\n";
#             my $en_verb = $cs2en_node{$cand_verb};
#             if ( $en_verb and grep { $_->lemma eq "it" } $en_verb->get_aux_anodes ) {
#                 $pleon_en_sum++;
#             }
#         }
#         elsif ( is_passive($cand_verb) ) {
#             my ( $perspron ) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated and $_->functor eq "PAT" } $cand_verb->get_echildren( { or_topological => 1 } );
#             if ( $perspron and $perspron->get_coref_nodes > 0 ) {
#                 $anaph_sum++;
#                 my @antecs = $perspron->get_coref_nodes;
#                 if ( grep { ($_->gram_sempos || "") eq "v" } @antecs ) {
#                     $segm_sum++;
#                 }
#             }
#             elsif ( $perspron ){
#                 $non_anaph_sum++;
#             }
#         }
#         elsif ( not is_passive($cand_verb) ) {
#             my ( $perspron ) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated and $_->functor eq "ACT" } $cand_verb->get_echildren( { or_topological => 1 } );
#             if ( $perspron and $perspron->get_coref_nodes > 0 ) {
#                 $anaph_sum++;
#                 my @antecs = $perspron->get_coref_nodes;
#                 if ( grep { ($_->gram_sempos || "") eq "v" } @antecs ) {
#                     $segm_sum++;
#                 }
#             }
#             elsif ( $perspron ){
#                 $non_anaph_sum++;
#             }
#         }
# #         pleonastic it
#         if ( not Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($cand_verb) ) {
# #             print PLEON_CS $cand_verb->get_address . "\n";
#         }
#         else {
#             my ( $perspron ) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $cand_verb->get_echildren( { or_topological => 1 } );
#             if ( $perspron and $perspron->get_coref_nodes > 0 ) {
# #                 print ANAPH_CS $perspron->get_address . "\n";
#             }
#             elsif ( $perspron ){
# #                 print NON_ANAPH_CS $perspron->get_address . "\n";
#             }
#         }
    }
# #         pleonastic it
#         if ( not is_passive_having_PAT($cand_verb)
#             and not is_active_having_ACT($cand_verb)
#         ) {
#             print PLEON_CS $cand_verb->get_address . "\n";
#         }
#         else {
#             my ( $perspron ) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $cand_verb->get_echildren( { or_topological => 1 } );
#             if ( $perspron and $perspron->get_coref_nodes > 0 ) {
#                 print ANAPH_CS $perspron->get_address . "\n";
#             }
#             elsif ( $perspron ){
#                 print NON_ANAPH_CS $perspron->get_address . "\n";
#             }
#         }
#     }
#     foreach my $cand_verb ( 
#         grep { 
#             ($_->gram_sempos || "") eq "v"
#             and not has_asubject($_) 
#             and is_3_sg_neut($_) } 
#         $cs_tree->get_descendants ) {
#         
#         if ( is_GEN($cand_verb) 
#             or is_IMPERS($cand_verb)
#             or has_sb_clause($cand_verb) ) {
#             print PLEON_CS $cand_verb->get_address . "\n";
#         }
#         else {
#             my ( $perspron ) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $cand_verb->get_echildren( { or_topological => 1 } );
#             if ( $perspron and $perspron->get_coref_nodes > 0 ) {
#                 print ANAPH_CS $perspron->get_address . "\n";
#             }
#             elsif ( $perspron ){
#                 print NON_ANAPH_CS $perspron->get_address . "\n";
#             }
#         }
#     }

#     close(ANAPH_CS);
#     close(NON_ANAPH_CS);
#     close(PLEON_CS);

#     print join "\t", ($anaph_sum, $non_anaph_sum, $pleon_sum, $pleon_en_sum, $segm_sum);
#     print "\n";
}

sub get_aligned_node {
    my ( $t_node ) = @_;
    my ($aligned, $types) = $t_node->get_directed_aligned_nodes;
    if ( $types ) {
        my $i;
        for ( $i = 0; $i < @{$types}; $i++ ) {
            last if ( $types->[$i] eq "monolingual" );
        }
        return $aligned->[$i];
    }
    return undef;
}

# monolingual
sub get_opposite_links {
    my ( $src_tree, $ref_tree ) = @_;
    my %ref2src_node;
    foreach my $src_node ( $src_tree->get_descendants ) {
        my $ref_node = get_aligned_node($src_node);
        $ref2src_node{$ref_node} = $src_node if ( $ref_node );
    }
    return %ref2src_node;
}

##------------------------------------------
#   cs_autom (src)    <-      cs_gold (ref)
#       |                           ^
#       v                           |
#   en_autom (src)    <-      en_gold (ref)
##------------------------------------------

# get the corresponding Czech automatic node for the given English one
sub get_en2cs_links {
    my ( $cs_tree ) = @_;
    my %en2cs_node;
    foreach my $cs_node ( $cs_tree->get_descendants ) {
        my ($aligned, $types) = $cs_node->get_directed_aligned_nodes;
        foreach my $en_node ( @{$aligned} ) {
            $en2cs_node{$en_node} = $cs_node;
        }
    }
    return %en2cs_node;
}

# get the corresponding English gold node for the given Czech one
sub get_cs2en_links {
    my ( $en_tree ) = @_;
    my %cs2en_node;
    foreach my $en_node ( $en_tree->get_descendants ) {
        my ($aligned, $types) = $en_node->get_directed_aligned_nodes;
        if ( $aligned ) {
            for ( my $i = 0; $i < @$aligned; $i++ ) {
                $cs2en_node{$aligned->[$i]} = $en_node if ( $types->[$i] ne "monolingual" );
            }
        }
    }
    return %cs2en_node;
}

sub test_it_en {
    my ( $en_tree ) = @_;
    foreach my $t_node ( $en_tree->get_descendants ) {
        my ($it) = grep { $_->lemma eq "it" } $t_node->get_anodes;
        my ($b_total, $b_eval) = (0, 0);
        if ( $it ) {
            my $verb;
            if ( ($t_node->gram_sempos || "") eq "v" ) {
                $verb = $t_node;
                $total_sum++;
                $b_total = 1;
            }
            else {
                ($verb) = $t_node->get_eparents( { or_topological => 1} );
            }
            if ( $verb 
                and ($verb->gram_sempos || "") eq "v"
                and ( en_has_ACT($verb, $t_node, $it)
                    or en_has_PAT($verb, $t_node, $it)
                    or make_it_to($verb, $t_node) )
#                 and grep { $_->functor eq "ACT"
#                     and $_ ne $t_node
#                     and not $_->is_generated
#                 } $verb->get_echildren( { or_topological => 1} )
#                 and $it->afun eq "Sb"
            ) {
# #                     There is a pleonastic "it"
#                 print $verb->get_address . "\n" if ( make_it_to($verb, $t_node) );
                $eval_sum++;
                $b_eval = 1;
                if ( $t_node->t_lemma ne "#PersPron" ) {
                    $correct_sum++;
                }
#                 else {
# #                     print $t_node->get_address . "\n";
#                 }
            }
            if ( $b_total and not $b_eval ) {
#                 print $t_node->get_address . "\n";
            }
        }
    }
    #print "$correct_sum\t$eval_sum\t$total_sum\n";
}

sub has_cs_sb {
    my ($verb) = @_;
    return ( Treex::Block::Eval::AddPersPronSb::has_subject($verb) ) ? 1 : 0;
}

sub has_cs_perspron {
    my ($verb) = @_;
    return ( Treex::Block::Eval::AddPersPronSb::will_have_perspron($verb) ) ? 1 : 0;
}

sub has_en_sb_clause {
    my ( $verb ) = @_;
    return (
        grep { ($_->gram_sempos || "") eq "v" 
            and $_->functor =~ /^(ACT|PAT)$/
        } $verb->get_echildren( { or_topological => 1 } ) 
    ) ? 1: 0;
}

sub is_be_having_sb_clause {
    my ( $verb ) = @_;
    if ( $verb->t_lemma eq "be" ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
        my @egrandchildren;
        foreach my $echild ( @echildren ) {
            push @egrandchildren, $echild->get_echildren( { or_topological => 1 } );
        }
        if ( grep { 
                ($_->gram_sempos || "") eq "v" and $_->functor =~ /^(ACT|PAT)$/
                or $_->formeme eq "v:to+inf"
            } @egrandchildren 
        ) {
            return 1;
        }
    }
    return 0;
}

# has an echild with formeme v:.*to+inf, or an echild with functor PAT and its echild has to+inf
sub has_v_to_inf {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^($to_clause_verbs)$/ ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
#         my @pats = grep { $_->functor eq "PAT" } @echildren;
#         foreach my $pat ( @pats ) {
#             push @echildren, $pat->get_echildren( { or_topological => 1 } );
#         }
        return 1 if ( grep { $_->formeme =~ /^v:.*to\+inf$/ } @echildren );
    }
    return 0;
}

# error case: make it <adj/noun> + <inf>: it is a child of <adj/noun> or <inf>
# looks for the word that precede it in the surface sentence, if it's make/take and has inf among children
sub has_v_to_inf_err {
    my ( $t_it, $t_tree) = @_;
    my $a_it = $t_it->get_lex_anode;
    if ( $a_it ) {
        my $a_ord = $a_it->ord - 1;
        my ($precendant) = grep { $_->get_lex_anode and $_->get_lex_anode->ord == $a_ord } $t_tree->get_descendants;
        if ( $precendant 
            and $precendant->t_lemma =~ /^($to_clause_verbs_pat)$/
            and grep { $_->formeme =~ /^v:.*to\+inf$/ } $precendant->get_echildren( { or_topological => 1 } )
        ) {
#             print $precendant->get_address . "\n";
#             $$p_verb = $precendant;
            return 1;
        }
    }
    return 0;
}

sub is_be_adj {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^($be_verbs)$/ ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
        my @pats = grep { $_->functor eq "PAT" and $_->formeme eq "adj:compl" } @echildren;
        foreach my $pat ( @pats ) {
            push @echildren, $pat->get_echildren( { or_topological => 1 } );
        }
        if ( @pats and grep { $_->formeme =~ /^v:.*fin$/ } @echildren) {
            return 1;
        }
    }
    return 0;
}

sub is_be_adj_err {
    my ( $verb ) = @_;
    if ( $verb->t_lemma =~ /^($be_verbs)$/ ) {
        my @echildren = $verb->get_echildren( { or_topological => 1 } );
        my @pats = grep { $_->functor eq "PAT" and $_->formeme =~ /^(adj:compl|n:obj)$/ } @echildren;
        foreach my $pat ( @pats ) {
            push @echildren, $pat->get_echildren( { or_topological => 1 } );
        }
        if ( @pats and grep { $_->formeme =~ /^v:/ } @echildren) {
            return 1;
        }
    }
    return 0;
}

sub has_possible {
    my ( $verb ) = @_;
    my @echildren = $verb->get_echildren( { or_topological => 1 } );
    return (
        grep { $_->t_lemma =~ /^($modal_adjs)$/
        } @echildren
        and grep { ($_->gram_sempos || "") eq "v"
        } @echildren
    ) ? 1 : 0;
}

sub is_seem {
    my ( $verb ) = @_;
    return (
        $verb->t_lemma eq "seem"
        and grep { $_->formeme =~ /^v:.*fin$/
        } $verb->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

sub has_cs_ACT_clause {
    my ( $en_verb, $cs_verb ) = @_;
    return (
        $en_verb->t_lemma =~ /^($be_verbs)$/
        and grep { $_->formeme =~ /^v:.*fin$/
            and $_->functor eq "ACT"
        } $cs_verb->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

sub find_short_sentences {
    my ( $en_tree ) = @_;
    
    my @descendants = $en_tree->get_descendants;
    if ( @descendants < 15 ) {
        foreach my $t_node ( @descendants ) {
            my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_anodes;
            if ( $a_it ) {
                my $verb = $t_node;
                my $cs_it = get_aligned_node($t_node);
                if ( ($verb->gram_sempos || "") ne "v" ) {
                    ($verb) = $t_node->get_eparents( { or_topological => 1} );
                }
                if ( ($verb->gram_sempos || "") eq "v" and $verb->t_lemma =~ /^(make|take)$/) {
#                     print $t_node->get_address . "\n";
                }
#                 elsif ( $verb->t_lemma eq "be" and grep { ($_->formeme || "") =~ /^(adj:compl|n:obj)$/} $verb->get_echildren ) {
#                     print $t_node->get_address . "\n";
#                 }
#                 elsif ( $verb->t_lemma =~ /^($cog_verbs|$cog_ed_verbs)$/ ) {
#                     print $t_node->get_address . "\n";
#                 }
                elsif ( has_cs_pp($cs_it) ) {
                    print $t_node->get_address . "\n";
                }
            }
        }
    }
}

sub is_cog_verb {
    my ( $verb ) = @_;
    return ( 
        ( $verb->t_lemma =~ /^($cog_ed_verbs)$/
            and $verb->get_lex_anode 
            and $verb->get_lex_anode->tag eq "VBN" 
        )
        or $verb->t_lemma =~ /^($cog_verbs)$/
    ) ? 1 : 0;
}

# error case: it can be said: be -> {it, say}
sub is_cog_ed_verb_err {
    my ( $verb ) = @_;
    return ( 
        $verb->t_lemma =~ /^(be|s)$/
        and grep { $_->t_lemma =~ /^($cog_ed_verbs)$/ } $verb->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

# English "it's" has a Czech equivalent "to"
sub has_cs_to {
    my ( $verb, $t_to ) = @_;
    return ( 
        $verb->t_lemma =~ /^($be_verbs)$/ 
        and $t_to 
        and $t_to->t_lemma eq "ten" 
        and $t_to->get_lex_anode 
        and $t_to->get_lex_anode->lemma eq "to"  
    ) ? 1 : 0;
}

sub has_cs_pp {
    my ( $t_node ) = @_;
    return (
        $t_node->t_lemma eq "#PersPron"
        or grep {
            $_->t_lemma eq "#PersPron"
        } $t_node->get_echildren( { or_topological => 1 } )
        
    ) ? 1 : 0;
}

sub has_cs_ten {
    my ( $cs_it ) = @_;
    return (
        $cs_it and $cs_it->t_lemma eq "ten"
    ) ? 1 : 0;
}

sub has_cs_noun {
    my ( $cs_it ) = @_;
    return (
        $cs_it
        and ($cs_it->gram_sempos || "") =~ /^n\.denot/
    ) ? 1 : 0;
}

sub has_cs_overt_perspron {
    my ( $cs_it ) = @_;
    return (
        $cs_it
        and $cs_it->t_lemma eq "#PersPron"
        and not $cs_it->is_generated
    ) ? 1 : 0;
}

sub get_en_it_total_sum {
    my ( $en_tree ) = @_;
    my $total_sum = 0;
    foreach my $t_node ( $en_tree->get_descendants ) {
        my $is_pleon = ( grep { $_->lemma eq "it"
                and $_->afun =~ /^Sb/
            } $t_node->get_aux_anodes
            and ($t_node->gram_sempos || "") eq "v"
            and not $t_node->is_generated 
        );
        my $is_non_anaph = ( $t_node->get_lex_anode 
            and $t_node->get_lex_anode->lemma eq "it" 
            and not $t_node->get_coref_nodes 
            and $t_node->get_lex_anode->afun =~ /^Sb/
        );
        if ( $is_non_anaph ) {
            my ($verb) = $t_node->get_eparents( { or_topological => 1 } );
            if ( not ( ($verb->gram_sempos || "") eq "v"
                    and not $verb->is_generated ) 
            ) {
                $is_non_anaph = 0;
            }
        }
#         if ( $is_pleon ) {
        if ( $is_pleon or $is_non_anaph ) {
            $total_sum++;
        }
    }
    return $total_sum;
}

sub get_non_ref_it_total {
    my ( $en_tree ) = @_;
    my $total_sum = 0;
    foreach my $t_node ( $en_tree->get_descendants ) {
        my $is_pleon = ( grep { $_->lemma eq "it"
            } $t_node->get_aux_anodes
        );
        my $is_non_anaph = ( $t_node->get_lex_anode 
            and $t_node->get_lex_anode->lemma eq "it" 
            and not $t_node->get_coref_nodes 
        );
        if ( $is_pleon or $is_non_anaph ) {
            $total_sum++;
        }
    }
    return $total_sum;
}

sub is_non_ref {
    my ( $gold_a_it, $gold_tree ) = @_;
    my ($is_pleon, $is_non_anaph);
    
    if ( $gold_a_it ) {
        foreach my $t_node ( $gold_tree->get_descendants ) {
            if ( grep { $_ eq $gold_a_it } $t_node->get_lex_anode ) {
                my ($antec) = $t_node->get_coref_nodes;
                if ( not $antec 
                    or ( $antec and ($antec->formeme || "") =~ /^v:/ )
                ) {
                    $is_non_anaph = 1;
                }
            }
            $is_pleon = grep { $_ eq $gold_a_it } $t_node->get_aux_anodes;
            return 1 if ( $is_non_anaph or $is_pleon );
        }
    }
    return 0;
}

# NADA + rule-based postprocessing
# tests NADA, error analysis
# tests through a_it
sub test_en_it_linked {
    my ( $bundle ) = @_;
    my $gold_cs_tree = $bundle->get_zone('cs', 'ref')->get_ttree;
    my $autom_cs_tree = $bundle->get_zone('cs', 'src')->get_ttree;
    my $gold_tree = $bundle->get_zone('en', 'ref')->get_ttree;
    my $autom_tree = $bundle->get_zone('en', 'src')->get_ttree;
    my $gold_atree = $bundle->get_zone('en', 'ref')->get_atree;
    my $autom_atree = $bundle->get_zone('en', 'src')->get_atree;
    my %autom2gold_node = get_opposite_links($gold_tree, $autom_tree);
    my %autom2gold_anode = get_opposite_links($gold_atree, $autom_atree);
    my %en2cs_node = get_en2cs_links($autom_cs_tree);
    my @eval_verbs;

    $total_sum += get_non_ref_it_total($gold_tree);
    foreach my $t_node ( $autom_tree->get_descendants ) {
        my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_lex_anode;
        if ( $a_it ) {
            my $gold_a_it = $autom2gold_anode{$a_it};
            if ( has_cs_ten($en2cs_node{$t_node}) ) {
                #print $t_node->get_address . "\n";
            }
            if ( not $t_node->wild->{"referential"}
                and not has_cs_noun($en2cs_node{$t_node})
                and not has_cs_overt_perspron($en2cs_node{$t_node})
            ) {
                $eval_sum++;
                if ( is_non_ref($gold_a_it, $gold_tree) ) {
                    $correct_sum++;
                }
            }
            else {
                my ($verb) = grep { ($_->gram_sempos || "") eq "v" } $t_node->get_eparents( { or_topological => 1} );
                if ( $verb
                    and ( has_v_to_inf($verb)
                        or is_be_adj($verb)
                        or is_cog_verb($verb)
#                         or has_v_to_inf_err($t_node, $autom_tree)
                        or is_be_adj_err($verb)
                        or is_cog_ed_verb_err($verb)
                        or has_cs_to($verb, $en2cs_node{$t_node})
                    ) 
                ) {
                    $eval_sum++;
                    if ( is_non_ref($gold_a_it, $gold_tree) ) {
                        $correct_sum++;
                    }
                }
                elsif ( has_v_to_inf_err($t_node, $autom_tree) 
#                     or has_cs_ten($en2cs_node{$t_node})
                ) {
                    $eval_sum++;
                    if ( is_non_ref($gold_a_it, $gold_tree) ) {
                        $correct_sum++;
                    }
                }
            }
        }
    }
#     print "$correct_sum\t$eval_sum\t$total_sum\n";
}


# NADA + rule-based postprocessing
# tests NADA, error analysis
# tests through t_it
sub test_en_it_linked_NADA_through_t_it {
    my ( $bundle ) = @_;
    my $gold_cs_tree = $bundle->get_zone('cs', 'ref')->get_ttree;
    my $autom_cs_tree = $bundle->get_zone('cs', 'src')->get_ttree;
    my $gold_tree = $bundle->get_zone('en', 'ref')->get_ttree;
    my $autom_tree = $bundle->get_zone('en', 'src')->get_ttree;
    my $gold_atree = $bundle->get_zone('en', 'ref')->get_atree;
    my $autom_atree = $bundle->get_zone('en', 'src')->get_atree;
    my %autom2gold_node = get_opposite_links($gold_tree, $autom_tree);
    my %autom2gold_anode = get_opposite_links($gold_atree, $autom_atree);
    my %en2cs_node = get_en2cs_links($autom_cs_tree);
    my @eval_verbs;

    $total_sum += get_non_ref_it_total($gold_tree);
    foreach my $t_node ( $autom_tree->get_descendants ) {
        my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_lex_anode;
        if ( $a_it ) {
            my $gold_a_it = $autom2gold_anode{$a_it};
            if ( not $t_node->wild->{"referential"} ) {
                $eval_sum++;
                if ( is_non_ref($gold_a_it, $gold_tree) ) {
                    $correct_sum++;
                }
            }
            else {
                my ($verb) = grep { ($_->gram_sempos || "") eq "v" } $t_node->get_eparents( { or_topological => 1} );
                if ( $verb
                    and (
                        not $t_node->wild->{"referential"}
                        or ( 
                            has_v_to_inf($verb)
                            or is_be_adj($verb)
                            or is_cog_verb($verb)
    #                         or has_v_to_inf_err($t_node, $autom_tree, \$verb)
    #                         or is_be_adj_err($verb)
    #                         or is_cog_ed_verb_err($verb)
    #                         or has_cs_to($verb, $en2cs_node{$t_node})
                        ) 
                    )
                ) {
                    $eval_sum++;
                    if ( is_non_ref($gold_a_it, $gold_tree) ) {
                        $correct_sum++;
                    }
                }
            }
            my ($verb) = grep { ($_->gram_sempos || "") eq "v" } $t_node->get_eparents( { or_topological => 1} );
            if ( $verb
                and (
                    not $t_node->wild->{"referential"}
                    or ( 
                        has_v_to_inf($verb)
                        or is_be_adj($verb)
                        or is_cog_verb($verb)
#                         or has_v_to_inf_err($t_node, $autom_tree, \$verb)
#                         or is_be_adj_err($verb)
#                         or is_cog_ed_verb_err($verb)
#                         or has_cs_to($verb, $en2cs_node{$t_node})
                    ) 
                )
            ) {
                $eval_sum++;
                if ( is_non_ref($gold_a_it, $gold_tree) ) {
                    $correct_sum++;
                }
#                 push @eval_verbs, $verb;
#                 my $gold_verb = $autom2gold_node{$verb};
#                 if ( $gold_verb ) {
#                     my @echildren = $gold_verb->get_echildren( { or_topological => 1 } );
#                     my $has_non_anaph = grep { $_->get_lex_anode and $_->get_lex_anode->lemma eq "it" and not $_->get_coref_nodes } @echildren;
#                     my $has_pleon = grep { $_->lemma eq "it" } ($gold_verb->get_aux_anodes, map { $_->get_aux_anodes } @echildren);
#                     if ( $has_non_anaph or $has_pleon ) {
#                         $correct_sum++;
#                     }
#                     else {
#     #                         print $verb->get_address . "\n";
#                     }
#                 }
            }
            elsif ( not $t_node->wild->{"referential"} ) {
                $eval_sum++;
                if ( is_non_ref($gold_a_it, $gold_tree) ) {
                    $correct_sum++;
                }
#                 my ($epar) = $t_node->get_eparents( { or_topological => 1 } );
#                 ($epar) = $epar->get_eparents( { or_topological => 1 } ) if ( $epar->formeme !~ /^v:/);
#                 my $gold_epar = $autom2gold_node{$epar} if ( $epar );
#                 if ( $gold_epar ) {
#                     push @eval_verbs, $epar;
#                     my @echildren = $gold_epar->get_echildren( { or_topological => 1 } );
#                     my $has_non_anaph = grep { $_->get_lex_anode and $_->get_lex_anode->lemma eq "it" and not $_->get_coref_nodes } @echildren;
#                     my $has_pleon = grep { $_->lemma eq "it" } ($gold_epar->get_aux_anodes, map { $_->get_aux_anodes } @echildren);
#                     if ( $has_non_anaph or $has_pleon ) {
#                         $correct_sum++;
#                     }
#                     else {
# #                         print $t_node->get_address . "\n";
#                     }
#                 }
            }
#             else {
#                 my $verb;
#                 if ( has_v_to_inf_err($t_node, $autom_tree, \$verb) ) {
#                     push @eval_verbs, $verb;
#                     my $gold_verb = $autom2gold_node{$verb};
#                     if ( $gold_verb ) {
#                         my @echildren = $gold_verb->get_echildren( { or_topological => 1 } );
#                         my $has_non_anaph = grep { $_->get_lex_anode and $_->get_lex_anode->lemma eq "it" and not $_->get_coref_nodes } @echildren;
#                         my $has_pleon = grep { $_->lemma eq "it" } ($gold_verb->get_aux_anodes, map { $_->get_aux_anodes } @echildren);
#                         if ( $has_non_anaph or $has_pleon ) {
#                             $correct_sum++;
#                         }
#                         else {
#         #                         print $verb->get_address . "\n";
#                         }
#                     }
#                 }
#             }
        }
    }

# # #     debug

    foreach my $t_node ( $gold_tree->get_descendants ) {
        my $is_pleon = ( grep { $_->lemma eq "it"
            } $t_node->get_aux_anodes
        );
        my $is_non_anaph = ( $t_node->get_lex_anode 
            and $t_node->get_lex_anode->lemma eq "it" 
            and not $t_node->get_coref_nodes 
        );
        if ( $is_pleon or $is_non_anaph ) {
            my ($autom_verb, $autom_parent_verb);
            if ( $is_non_anaph ) {
                my $autom_it = fned_node($t_node);
                ($autom_verb) = $autom_it->get_eparents( { or_topological => 1 } ) if ( $autom_it );
                ($autom_parent_verb) = $autom_verb->get_eparents( { or_topological => 1 } ) if ( $autom_verb );
            }
            else {
                $autom_verb = get_aligned_node($t_node);
                my ($par) = $t_node->get_eparents( { or_topological => 1 } );
                $autom_parent_verb = get_aligned_node($par) if ( $par );
                
            }
            if ( $is_pleon ) {
                if ( $autom_verb and not grep { $_ eq $autom_verb} @eval_verbs ) {
                    if ( $autom_parent_verb and not grep { $_ eq $autom_parent_verb } @eval_verbs ) {
                        print $autom_verb->get_address . "\n";
                    }
                }
            }
        }
    }
}

# tests NADA
sub test_en_it_linked_NADA {
    my ( $gold_tree, $autom_tree, $autom_cs_tree ) = @_;
    my %autom2gold_node = get_opposite_links($gold_tree, $autom_tree);
    my %en2cs_node = get_en2cs_links($autom_cs_tree);
    my @eval_verbs;

    $total_sum += get_non_ref_it_total($gold_tree);
    foreach my $t_node ( $autom_tree->get_descendants ) {
        my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_lex_anode;
        if ( $a_it and not $t_node->wild->{referential} ) {
            my ($verb) = grep { ($_->gram_sempos || "") eq "v" } $t_node->get_eparents( { or_topological => 1} );
            if ( $verb ) {
                $eval_sum++;
                push @eval_verbs, $verb;
                my $gold_verb = $autom2gold_node{$verb};
                if ( $gold_verb ) {
                    my @echildren = $gold_verb->get_echildren( { or_topological => 1 } );
                    my $has_non_anaph = grep { $_->get_lex_anode and $_->get_lex_anode->lemma eq "it" and not $_->get_coref_nodes } @echildren;
                    my $has_pleon = grep { $_->lemma eq "it" } ($gold_verb->get_aux_anodes, map { $_->get_aux_anodes } @echildren);
                    my @anodes = ($gold_verb->get_aux_anodes, map { $_->get_aux_anodes } @echildren);
                    if ( $has_non_anaph or $has_pleon ) {
                        $correct_sum++;
                    }
                    else {
    #                         print $verb->get_address . "\n";
                    }
                }
            }
        }
    }
#     debug
#     foreach my $t_node ( $gold_tree->get_descendants ) {
#         my $is_pleon = ( grep { $_->lemma eq "it"
#             } $t_node->get_aux_anodes
#         );
#         my $is_non_anaph = ( $t_node->get_lex_anode 
#             and $t_node->get_lex_anode->lemma eq "it" 
#             and not $t_node->get_coref_nodes 
#         );
#         if ( $is_pleon or $is_non_anaph ) {
#             my ($autom_verb, $autom_parent_verb);
#             if ( $is_non_anaph ) {
#                 my $autom_it = get_aligned_node($t_node);
#                 ($autom_verb) = $autom_it->get_eparents( { or_topological => 1 } ) if ( $autom_it );
#                 ($autom_parent_verb) = $autom_verb->get_eparents( { or_topological => 1 } ) if ( $autom_verb );
#             }
#             else {
#                 $autom_verb = get_aligned_node($t_node);
#                 my ($par) = $t_node->get_eparents( { or_topological => 1 } );
#                 $autom_parent_verb = get_aligned_node($par) if ( $par );
#                 
#             }
#             if ( $autom_verb and not grep { $_ eq $autom_verb} @eval_verbs ) {
#                 if ( $autom_parent_verb and not grep { $_ eq $autom_parent_verb } @eval_verbs ) {
#                     print $autom_verb->get_address . "\n";
#                 }
#             }
#         }
#     }
}

sub test_en_it_linked_nada_specialized {
    my ( $gold_tree, $autom_tree, $autom_cs_tree ) = @_;
    my %autom2gold_node = get_opposite_links($gold_tree, $autom_tree);
    my %en2cs_node = get_en2cs_links($autom_cs_tree);
    my @eval_verbs;
    $total_sum += get_en_it_total_sum($gold_tree);
    foreach my $t_node ( $autom_tree->get_descendants ) {
        my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_lex_anode;
#         na automatickych datech maji vsechna it uzel #PersPron, nejsou nikama schovana!
#         my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_anodes;
        if ( $a_it 
            and $a_it->afun =~ /^Sb/
        ) {
#             print $t_node->get_address . "\n";
            my $verb;
            if ( $t_node->t_lemma ne "#PersPron" ) {
                $verb = $t_node;
#                 $total_sum++;
            }
            else {
                ($verb) = $t_node->get_eparents( { or_topological => 1} );
            }
            if ( $verb
                and ($verb->gram_sempos || "") eq "v" 
                and (
                    not $t_node->wild->{"referential"}
                    or ( 
                        has_v_to_inf($verb)
                        or is_be_adj($verb)
                    ) 
#                     or ( grep { ($_->gram_sempos || "") eq "v" } $verb->get_echildren( { or_topological => 1} ) ) 
                )
            ) {
#                 print $t_node->get_address . "\n";
                push @eval_verbs, $verb;
                $eval_sum++;
                my $gold_verb = $autom2gold_node{$verb};
                if ( $gold_verb ) {
#                     if ( $gold_verb->id eq "EnglishT-wsj_1102-s17-t10" ) {
#                         print "tady jsme\n";
#                     }
                    my @echildren = $gold_verb->get_echildren( { or_topological => 1 } );
                    my ($non_pleon_it) = grep { $_->t_lemma eq "#PersPron" and $_->get_lex_anode and $_->get_lex_anode->lemma eq "it" } @echildren;
                    my @anodes = ($gold_verb->get_aux_anodes, map { $_->get_aux_anodes } @echildren);
#                     print join "\t", map { $_->form } @anodes;
#                     print "\n";
                    if ( grep { $_->lemma eq "it" } @anodes 
                        or ( $non_pleon_it and not $non_pleon_it->get_coref_nodes ) 
                    ) {
                        $correct_sum++;
                    }
                    else {
#                         print $verb->get_address . "\n";
                    }
                }
            }
        }
    }

    foreach my $t_node ( $gold_tree->get_descendants ) {
        my $is_pleon = ( grep { $_->lemma eq "it"
                and $_->afun =~ /^Sb/
            } $t_node->get_aux_anodes
            and ($t_node->gram_sempos || "") eq "v"
            and not $t_node->is_generated );
        my $is_non_anaph = ( $t_node->get_lex_anode 
            and $t_node->get_lex_anode->lemma eq "it" 
            and not $t_node->get_coref_nodes 
            and $t_node->get_lex_anode->afun =~ /^Sb/ 
            and ($t_node->gram_sempos || "") eq "v"
            and not $t_node->is_generated );
        if ( $is_non_anaph ) {
            my ($verb) = $t_node->get_eparents( { or_topological => 1 } );
            if ( not ( ($verb->gram_sempos || "") eq "v"
                    and not $verb->is_generated ) 
            ) {
                $is_non_anaph = 0;
            }
        }
        if ( $is_pleon or $is_non_anaph ) {
            my ($verb) = $t_node->get_eparents( { or_topological => 1 } );
            $verb = $t_node if ( $is_pleon );
            my $autom_verb = get_aligned_node($verb);
            if ( $autom_verb and not grep { $_ eq $autom_verb} @eval_verbs ) {
                my ($parent) = $autom_verb->get_eparents( { or_topological => 1 } );
                if ( $parent and not grep { $_ eq $parent } @eval_verbs ) {
                    print $autom_verb->get_address . "\n";
                }
            }
        }
    }

#     print "$correct_sum\t$eval_sum\t$total_sum\n";
}


sub test_en_it_linked_without_nada {
    my ( $gold_tree, $autom_tree, $autom_cs_tree ) = @_;
    my %autom2gold_node = get_opposite_links($gold_tree, $autom_tree);
    my %en2cs_node = get_en2cs_links($autom_cs_tree);
    
    my %to_inf;
    $total_sum += get_en_it_total_sum($gold_tree);
#     foreach my $t_node ( $gold_tree->get_descendants ) {
#         my ($a_it) = grep { $_->form =~ /^[iI][tT]$/ } $t_node->get_anodes;
#         if ( $a_it and $t_node->t_lemma ne "#PersPron" ) {
#             my $cs_node = get_aligned_node($t_node);
#             my $verb;
#             if ( $cs_node and $cs_node->t_lemma ne "#PersPron" ) {
#                 $verb = $cs_node;
# #                 $total_sum++;
#             }
#             else {
#                 ($verb) = $cs_node->get_eparents( { or_topological => 1} );
#             }
#             if ( $verb
#                 and grep { $_->functor eq "ACT"
#                     and $_ ne $cs_node
#                     and not $_->is_generated
#                     } $verb->get_echildren( { or_topological => 1} )
#                 and $a_it->afun eq "Sb"
#             ) {
#                 print $cs_node->get_address . "\n";
#             }
#             
# #             print $t_node->get_address . "\n";
#         }
#     }
    my @eval_verbs;
    foreach my $t_node ( $autom_tree->get_descendants ) {
        my ($a_it) = grep { $_->lemma eq "it" } $t_node->get_anodes;
        if ( $a_it ) {
            my $verb;
            if ( $t_node->t_lemma ne "#PersPron" ) {
                $verb = $t_node;
#                 $total_sum++;
            }
            else {
                ($verb) = $t_node->get_eparents( { or_topological => 1} );
            }
#             my $halo = ( $t_node->id eq "t_tree-en_src-s8-n165" ) ? 1 : 0;
            if ( $verb
                and ($verb->gram_sempos || "") eq "v"
                and ( 
#                     en_has_ACT($verb, $t_node, $a_it)
#                     or en_has_PAT($verb, $t_node, $a_it)
                    has_v_to_inf($verb)
                    or is_be_adj($verb)
#                     or is_cog_verb($verb)
#                     or ( $en2cs_node{$verb} and has_cs_ACT_clause($verb, $en2cs_node{$verb}) )
#                     or ( $en2cs_node{$t_node} and has_cs_to($en2cs_node{$t_node}) )
                ) 
# #                     has_en_sb_clause($verb) # 4 15 12
#                     or make_it_to($verb, $t_node) # 3 10 15
#                     or is_seem($verb)
#                     or has_possible($verb)
# #                     or is_be_having_sb_clause($verb)
# #                     or has_en_sb_clause($verb) # 4 24 8
# #                     or ( $en2cs_node{$verb} and has_cs_sb($en2cs_node{$verb}) ) # 5 28 8
# #                 and ( $en2cs_node{$verb} and not has_cs_perspron($en2cs_node{$verb}) ) # 3 6 12
# #                     or ( $en2cs_node{$verb} and not has_cs_perspron($en2cs_node{$verb}) ) # 5 29 8
# #                 and ( $en2cs_node{$verb} and has_cs_sb($en2cs_node{$verb}) ) # 3 7 15
# #                     or ( $en2cs_node{$verb} and has_cs_sb($en2cs_node{$verb}) ) # 6 51 15
# #                 grep { $_->functor eq "ACT"
# #                     and $_ ne $t_node
# #                     and not $_->is_generated
# #                     } $verb->get_echildren( { or_topological => 1} )
# #                 and $a_it->afun eq "Sb"
            ) {
# #                     There is a pleonastic "it"
                $eval_sum++;
                push @eval_verbs, $verb;
#                 if ( $halo ) {
#                     print join "\t", ($t_node->t_lemma, $verb->t_lemma);
#                     print "\n";
#                 }
#                 print $verb->get_address . "\n";
#                 print $verb->t_lemma . "\n";
#                 print join "\t", map { $_->form } $verb->get_anodes;
#                 print "\n";
#                 print joing "\t", map { $_->t_lemma } $verb->get_echildren;
#                 print "\n";
                my $gold_verb = $autom2gold_node{$verb};
                if ( $gold_verb ) {
                    my @anodes = ($gold_verb->get_aux_anodes, map { $_->get_aux_anodes } $gold_verb->get_echildren( { or_topological => 1 } ));
                    if ( grep { $_->lemma eq "it" } @anodes ) {
                        $correct_sum++;
#                         if ( $verb->t_lemma =~ /^(be|s)$/ and grep { $_->formeme =~ /^v:.*fin/ } $verb->get_echildren( { or_topological => 1 } ) ) {
#                             print $verb->get_address . "\n";
#                         }
#                         if (grep { $_->formeme =~ /^v:.*to\+inf/ } $verb->get_echildren( { or_topological => 1 } )) {
#                             my (@pats) = grep { $_->functor eq "PAT" } $verb->get_echildren( { or_topological => 1 } );
#                             foreach my $pat ( @pats ) {
#                                 if (grep { $_->formeme =~ /^v:.*to\+inf/ } $pat->get_echildren( { or_topological => 1 } )) {
#                                     print $verb->get_address . "\n";
#                                     $to_inf{$pat->t_lemma}++;
#                                 }
#                                 
#                             }
# #                             $to_inf{$verb->t_lemma}++;
#                         }
                    }
                    else {
#                         print $verb->get_address . "\n";
                    }
                }
                else {
#                     print $t_node->get_address . "\n";
                }
            }
        }
    }
#     foreach my $t_node ( $gold_tree->get_descendants ) {
#         if ( grep { $_->lemma eq "it" and $_->afun =~ /^Sb/ } $t_node->get_aux_anodes
#             and ($t_node->gram_sempos || "") eq "v"
#         ) {
#             my $autom_verb = get_aligned_node($t_node);
#                     if ( $autom_verb and not grep { $_ eq $autom_verb} @eval_verbs ) {
#                         print $autom_verb->get_address . "\n";
#                     }
# #             if ( $autom_verb and not grep { $_ eq $autom_verb} @eval_verbs ) {
# #                 if ( ($t_node->parent->gram_sempos || "") eq "v" ) {
# #                     $autom_verb = get_aligned_node($t_node->parent);
# #                     if ( $autom_verb and not grep { $_ eq $autom_verb} @eval_verbs ) {
# #                         print $autom_verb->get_address . "\n";
# #                     }
# #                 }
# #             }
#         }
#     }

    print "$correct_sum\t$eval_sum\t$total_sum\n";

#     if ( %to_inf ) {
#         print join "\t", keys %to_inf;
#         print "\n"
#     }
}

sub has_perspron {
    my ( $t_node ) = @_;
    return ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $t_node->get_echildren ( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

# TODO spocitat znovu total_sum pro CS
sub test_it_cs {
    my ( $cs_tree ) = @_;

     $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_pleon_sb($_) and is_3_sg($_) and not $_->is_generated } $cs_tree->get_descendants;
    
     my @all_cands = grep {
        ($_->gram_sempos || "") eq "v"
        and is_3_sg($_)
        and not $_->is_generated
#         and not Treex::Block::Eval::AddPersPronSb::has_subject($_)
        and not Treex::Block::Eval::AddPersPronSb::has_subject_gold($_)
    } $cs_tree->get_descendants;
    
    my @eval_verbs;
    foreach my $cand_verb (@all_cands) {
        $allcands_sum++;
        
        my $is_true = 
#             Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($cand_verb) or
            Treex::Block::Eval::AddPersPronSb::has_pleon_sb($cand_verb);
        my $is_selected =
            Treex::Block::Eval::AddPersPronSb::will_have_pleon_gold($cand_verb);
#             not Treex::Block::Eval::AddPersPronSb::will_have_perspron_gold($cand_verb);

        if ($is_selected && $is_true) {
            $correct_sum++;
            push @eval_verbs, $cand_verb;
        }
        if ($is_selected) {
            $eval_sum++;
        }
#         if ($is_true) {
#             $total_sum++;
#         }
    }
    
    foreach my $verb ( grep { Treex::Block::Eval::AddPersPronSb::has_pleon_sb($_) and is_3_sg($_) and not $_->is_generated } $cs_tree->get_descendants ) {
        if ( not grep { $_ eq $verb } @eval_verbs ) {
            print $verb->get_address . "\n";
        }
    }
}


##     $total_sum += grep { has_perspron($_) and is_3_sg_neut($_) and not $_->is_generated } $cs_tree->get_descendants;
#      $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_pleon_sb($_) and is_3_sg($_) and not $_->is_generated } $cs_tree->get_descendants;
#      $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg($_) and not $_->is_generated } $cs_tree->get_descendants;
##     $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg_neut($_) and not $_->is_generated } $cs_tree->get_descendants;
##     $total_sum += Treex::Block::Eval::AddPersPronSb::get_total_sum($cs_tree);
#    
#    my @eval_verbs;
#    foreach my $cand_verb (
#        grep { 
#            ($_->gram_sempos || "") eq "v"
#            and is_3_sg($_)
##             and is_3_sg_neut($_)
#            and not $_->is_generated
#            and not Treex::Block::Eval::AddPersPronSb::has_subject_gold($_)
#        } $cs_tree->get_descendants
#    ) {
#        $allcands_sum++;
#        if ( 
##             not Treex::Block::Eval::AddPersPronSb::has_subject_gold($cand_verb) and
#             not Treex::Block::Eval::AddPersPronSb::will_have_perspron_gold($cand_verb) ) {
##        if ( Treex::Block::Eval::AddPersPronSb::will_have_pleon_gold($cand_verb) ) {
#            $eval_sum++;
#            push @eval_verbs, $cand_verb;
#            if ( Treex::Block::Eval::AddPersPronSb::has_pleon_sb($cand_verb) || 
#                 Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($cand_verb) ) {
##             if ( has_perspron($cand_verb) ) {
#                $correct_sum++;
#            }
#            else {
##                 print $cand_verb->get_address . "\n";
#            }
#        }
#        elsif ( Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($cand_verb) ) {
##             print $cand_verb->get_address . "\n";
#        }
#    }
#    foreach my $correct_verb ( grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg($_) and not $_->is_generated } $cs_tree->get_descendants ) {
##     foreach my $correct_verb ( grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg_neut($_) and not $_->is_generated } $cs_tree->get_descendants ) {
#        if ( not grep { $_ eq $correct_verb } @eval_verbs ) {
#            print $correct_verb->get_address . "\n";
#        }
#    }
#    #print "$correct_sum\t$eval_sum\t$total_sum\n";
#}

sub has_en_perspron {
    my ( $cs_verb ) = @_;
    my ($aligned, $types) = $cs_verb->get_directed_aligned_nodes;
#     my $en_verb = get_aligned_node($cs_verb);
#     if ( $aligned ) {
    my $i = 0;
    while ( $aligned->[$i] ) {
        if ( ($aligned->[$i]->gram_sempos || "") eq "v" ) {
            my $en_verb = $aligned->[$i];
            my @persprons = grep { $_->t_lemma eq "#PersPron" } $en_verb->get_echildren ( { or_topological => 1 } );
            if ( grep { $_->get_lex_anode 
                    and $_->get_lex_anode->lemma =~ /^(he|she|they)$/
                    and $_->get_lex_anode->afun =~ /^Sb/ 
                } @persprons
            ) {
#                     if ( $cs_verb->id eq "t_tree-cs_src-s2-n901" ) {
# #                         print "tady jsme\n";
#                     }
                return 1;
            }
            return 0;
        }
        else {
            $i++;
        }
    }
#     print $cs_verb->get_address . "\n";
    return 0;
}

sub has_en_sb {
    my ( $cs_verb ) = @_;
    my ($aligned, $types) = $cs_verb->get_directed_aligned_nodes;
    my $i = 0;
    while ( $aligned->[$i] ) {
        if ( ($aligned->[$i]->gram_sempos || "") eq "v" ) {
            my $en_verb = $aligned->[$i];
    #     my $en_verb = get_aligned_node($cs_verb);
    #     if ( $en_verb ) {
            if ( grep {
                    $_->t_lemma ne "#PersPron"
                    and $_->get_lex_anode
                    and $_->get_lex_anode->afun =~ /^Sb/
                } $en_verb->get_echildren ( { or_topological => 1 } )
            ) {
#                 print $cs_verb->get_address . "\n";
                return 1;
            }
#             foreach my $echild ( $en_verb->get_echildren ( { or_topological => 1 } ) ) {
#                 if ( $echild->t_lemma ne "#PersPron"
#                     and $echild->get_lex_anode
#                     and $echild->get_lex_anode->afun =~ /^Sb/ ) {
#     #                 print $cs_verb->get_address . "\n";
#                     return 1;
#                 }
#             }
            return 0;
        }
        else {
            $i++;
        }
    }
    return 0;
}

sub get_cs_total {
    my ( $gold_tree ) = @_;
    return grep {
        Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb_gold($_)
        and is_3_sg($_)
#         and is_3_sg_neut($_)
        and not $_->is_generated
        and has_en_perspron($_)
    } $gold_tree->get_descendants;
}

sub test_cs_it_linked {
    my ( $gold_tree, $autom_tree ) = @_;
    my %autom2gold_node = get_opposite_links($gold_tree, $autom_tree);
    
#     $total_sum += get_cs_total($gold_tree);
    $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_pleon_sb($_) and is_3_sg($_) and not $_->is_generated } $gold_tree->get_descendants;
#     $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg($_) and not $_->is_generated } $gold_tree->get_descendants;
#     $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg_neut($_) and not $_->is_generated } $gold_tree->get_descendants;
    my @eval_verbs;
    foreach my $cand_verb (
        grep { 
            ($_->gram_sempos || "") eq "v"
            and is_3_sg($_)
#             and is_3_sg_neut($_)
            and not $_->is_generated
        } $autom_tree->get_descendants
    ) {
        $allcands_sum++;
        if ( (Treex::Block::Eval::AddPersPronSb::will_have_perspron($cand_verb)
#        if ( (Treex::Block::Eval::AddPersPronSb::will_have_pleon($cand_verb)
#            or has_en_perspron($cand_verb)
            )
    #        and not has_en_sb($cand_verb)
            ) {
#         if ( (Treex::Block::Eval::AddPersPronSb::will_have_perspron($cand_verb)
#             or has_en_perspron($cand_verb))
#             and not has_en_sb($cand_verb)
#             ) {
            $eval_sum++;
            push @eval_verbs, $cand_verb;
            my $gold_verb = $autom2gold_node{$cand_verb};
            if ( $gold_verb ) {
                if ( $gold_verb->gram_sempos =~ /^adj\.denot/ ) {
                    my ($epar) = $gold_verb->get_eparents( { or_topological => 1 } );
                    $gold_verb = $epar if ( $epar and $epar->t_lemma eq "být" );
                }
                if ( Treex::Block::Eval::AddPersPronSb::has_pleon_sb($gold_verb) ) {
#                 if ( Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($gold_verb) ) {
                    $correct_sum++;
        #             find short sentences
                    my @descendants = $autom_tree->get_descendants;
                    if ( @descendants < 15 ) {
                        if ( not Treex::Block::Eval::AddPersPronSb::will_have_perspron($cand_verb)
                            and has_en_perspron($cand_verb) 
                        ) {
#                             if ( $cand_verb->id eq "t_tree-cs_src-s2-n97" 
#         #                         and not Treex::Block::Eval::AddPersPronSb::is_active_having_ACT($cand_verb)
#                             ) {
#                                 print $cand_verb->get_address . "\n";
#                             }
                            print $cand_verb->get_address . "\n";
                        }
                    }
        # end find
                }
                else {
#                     print $cand_verb->get_address . "\n";
                }
#                 if ( $cand_verb->id eq "t_tree-cs_src-s3-n91" ) {
#                     if ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $gold_verb->get_echildren ( { or_topological => 1 } ) ) {
#                         Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb_debug($gold_verb);
#                     }
#                     
#                 }
            }
        }
    }
#     foreach my $gold_verb ( grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg($_) and not $_->is_generated } $gold_tree->get_descendants ) {
# #     foreach my $gold_verb ( grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg_neut($_) and not $_->is_generated } $gold_tree->get_descendants ) {
#         my $autom_verb = get_aligned_node($gold_verb);
#         if ( $autom_verb and not grep { $_ eq $autom_verb } @eval_verbs ) {
#             print $autom_verb->get_address . "\n";
#         }
#     }
#     print "$correct_sum\t$eval_sum\t$total_sum\n";
}

# process PCEDT 2.0 linked manually and automatically annotated data
# sub process_bundle_linked {
sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $gold_cs_tree = $bundle->get_zone('cs', 'ref')->get_ttree;
    my $autom_cs_tree = $bundle->get_zone('cs', 'src')->get_ttree;
    my $gold_en_tree = $bundle->get_zone('en', 'ref')->get_ttree;
    my $autom_en_tree = $bundle->get_zone('en', 'src')->get_ttree;

#     test_it_en($gold_en_tree);
#     test_it_cs($gold_cs_tree);
#     test_cs_it_linked($gold_cs_tree, $autom_cs_tree);
#    test_en_it_linked($bundle);
#     find_short_sentences($gold_en_tree, $gold_cs_tree);
    analyze_cs($gold_cs_tree, $gold_en_tree);
#     analyze_en($gold_en_tree);
}

# process PCEDT 2.0 manually annotated data
sub process_bundle_manual {
# sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en_tree = $bundle->get_zone('en')->get_ttree;
    my $cs_tree = $bundle->get_zone('cs')->get_ttree;

#     analyze_en($en_tree);
    analyze_cs($cs_tree, $en_tree);
#     test_it_en($en_tree);
#     test_it_cs($cs_tree);
}

sub process_end {
#     my $tp = $correct_sum;
#     my $fp = $eval_sum - $tp;
#     my $fn = $total_sum - $tp;
#     my $tn = $allcands_sum - ($tp + $fp + $fn); 
#     print join "\t", ($tp, $tn, $fp, $fn);
#     print "\n";
#     print STDERR "$correct_sum\t$eval_sum\t$total_sum\n";
#     print join "\t", ($anaph_sum, $non_anaph_sum, $pleon_sum, $pleon_cs_sum, $segm_sum, $to_sum, $pp_sum);
    print join "\t", ($anaph_sum, $non_anaph_sum, $pleon_sum, $pleon_en_sum, $segm_sum);
    print "\n";
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Eval::AddPersPronIt

=head1 DESCRIPTION

Analyzing English pleonastic it and its corresponding Czech occurence on PCEDT 2.0 data.

=head1 AUTHORS

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

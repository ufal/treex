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

my ($correct_sum, $eval_sum, $total_sum) = (0, 0 ,0);

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
            and grep { $_->tag =~ /^V.......P/ } @anodes 
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

    open(ANAPH, ">>:encoding(UTF-8)", $anaph_path) || die "Can't open $anaph_path: $!";
    open(NON_ANAPH, ">>:encoding(UTF-8)", $non_anaph_path) || die "Can't open $non_anaph_path: $!";
    open(PLEON, ">>:encoding(UTF-8)", $pleon_path) || die "Can't open $pleon_path: $!";
    
    foreach my $t_node ( $en_tree->get_descendants ) {
        if ( grep { $_->form =~ /^[iI][tT]$/ } $t_node->get_anodes ) {
            if ( $t_node->t_lemma ne "#PersPron" ) {
                print PLEON $t_node->get_address . "\n";
            }
            elsif ( $t_node->get_coref_nodes > 0 ) {
                print ANAPH $t_node->get_address . "\n";
            }
            else {
                print NON_ANAPH $t_node->get_address . "\n";
            }
        }
    }

    close(ANAPH);
    close(NON_ANAPH);
    close(PLEON);
}

sub get_en_it_total_sum {
    my ( $en_tree ) = @_;
    my $total_sum = 0;
    foreach my $t_node ( $en_tree->get_descendants ) {
        if ( grep { $_->form =~ /^[iI][tT]$/ } $t_node->get_anodes
            and $t_node->t_lemma ne "#PersPron"
        ) {
            $total_sum++;
        }
    }
    return $total_sum;
}

sub en_has_ACT {
    my ($verb, $t_node, $it) = @_;
    return (
        ($verb->gram_sempos || "") eq "v"
#         $verb->get_lex_anode and $verb->get_lex_anode->tag =~ /^V/
        and grep { $_->functor eq "ACT"
            and $_ ne $t_node
            and not $_->is_generated
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
        } $verb->get_echildren( { or_topological => 1} )
        and $it->afun eq "Sb"
    ) ? 1 : 0;
}

sub make_it_to {
    my ($verb, $t_node, $it) = @_;
    return (
        $verb->t_lemma eq "make"
        and grep { $_->functor eq "PAT"
            and $_ ne $t_node
            and not $_->is_generated
        } $verb->get_echildren( { or_topological => 1} )
    ) ? 1 : 0;
}

sub test_it_en {
    my ( $en_tree ) = @_;
    foreach my $t_node ( $en_tree->get_descendants ) {
        my ($it) = grep { $_->form =~ /^[iI][tT]$/ } $t_node->get_anodes;
        my ($b_total, $b_eval) = (0, 0);
        if ( $it ) {
            my $verb;
            if ( $t_node->t_lemma ne "#PersPron" ) {
                $verb = $t_node;
                $total_sum++;
                $b_total = 1;
            }
            else {
                ($verb) = $t_node->get_eparents( { or_topological => 1} );
            }
            if ( $verb 
                and ( en_has_ACT($verb, $t_node, $it)
                    or en_has_PAT($verb, $t_node, $it)
                    or make_it_to($verb, $t_node, $it) )
#                 and grep { $_->functor eq "ACT"
#                     and $_ ne $t_node
#                     and not $_->is_generated
#                 } $verb->get_echildren( { or_topological => 1} )
#                 and $it->afun eq "Sb"
            ) {
# #                     There is a pleonastic "it"
                $eval_sum++;
                $b_eval = 1;
                if ( $t_node->t_lemma ne "#PersPron" ) {
                    $correct_sum++;
                }
                else {
#                     print $t_node->get_address . "\n";
                }
            }
            if ( $b_total and not $b_eval ) {
#                 print $t_node->get_address . "\n";
            }
        }
    }
    print "$correct_sum\t$eval_sum\t$total_sum\n";
}

# returns 1 if the given node is a passive verb
sub is_passive {
    my ($t_node) = @_;
    return (  ( $t_node->get_lex_anode and $t_node->get_lex_anode->tag =~ /^Vs/ )
        or is_refl_pass($t_node)
    ) ? 1 : 0;
}

# returns 1 if the given node is an passive verb and has an echild with PAT => possibly has an overt subject
# PAT can be an expressed word or a #PersPron drop
sub is_passive_having_PAT {
    my ( $t_node ) = @_;
    return ( is_passive($t_node)
        and grep { ($_->functor || "" ) eq "PAT" 
            and ( not $_->is_generated or $_->t_lemma eq "#PersPron" ) } $t_node->get_echildren( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

# returns 1 if the given node is an active verb and has an echild with ACT => possibly has an overt subject
# ACT can be an expressed word or a #PersPron drop
sub is_active_having_ACT {
    my ( $t_node ) = @_;
    return ( not is_passive($t_node)
        and grep { ($_->functor || "" ) eq "ACT" 
            and ( not $_->is_generated or $_->t_lemma eq "#PersPron" ) } $t_node->get_echildren( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

sub analyze_cs {
    my ( $cs_tree ) = @_;

    open(ANAPH_CS, ">>:encoding(UTF-8)", $anaph_path_cs) || die "Can't open $anaph_path_cs: $!";
    open(NON_ANAPH_CS, ">>:encoding(UTF-8)", $non_anaph_path_cs) || die "Can't open $non_anaph_path_cs: $!";
    open(PLEON_CS, ">>:encoding(UTF-8)", $pleon_path_cs) || die "Can't open $pleon_path_cs: $!";
    
    foreach my $cand_verb (
        grep { 
            ($_->gram_sempos || "") eq "v"
            and is_3_sg_neut($_)
            and not $_->is_generated
        } $cs_tree->get_descendants
    ) {
#         pleonastic it
        if ( not Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($cand_verb) ) {
            print PLEON_CS $cand_verb->get_address . "\n";
        }
        else {
            my ( $perspron ) = grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $cand_verb->get_echildren( { or_topological => 1 } );
            if ( $perspron and $perspron->get_coref_nodes > 0 ) {
                print ANAPH_CS $perspron->get_address . "\n";
            }
            elsif ( $perspron ){
                print NON_ANAPH_CS $perspron->get_address . "\n";
            }
        }
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

    close(ANAPH_CS);
    close(NON_ANAPH_CS);
    close(PLEON_CS);
}

sub test_it_cs {
    my ( $cs_tree ) = @_;

    $total_sum += grep { Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($_) and is_3_sg_neut($_) and not $_->is_generated } $cs_tree->get_descendants;
#     $total_sum += Treex::Block::Eval::AddPersPronSb::get_total_sum($cs_tree);
    
    foreach my $cand_verb (
        grep { 
            ($_->gram_sempos || "") eq "v"
            and is_3_sg_neut($_)
            and not $_->is_generated
        } $cs_tree->get_descendants
    ) {
        if ( Treex::Block::Eval::AddPersPronSb::will_have_perspron($cand_verb) ) {
            $eval_sum++;
            if ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $cand_verb->get_echildren ( { or_topological => 1 } ) ) {
                $correct_sum++;
            }
            else {
#                 print $cand_verb->get_address . "\n";
            }
        }
        elsif ( Treex::Block::Eval::AddPersPronSb::has_unexpressed_sb($cand_verb) ) {
#             print $cand_verb->get_address . "\n";
        }
    }
    print "$correct_sum\t$eval_sum\t$total_sum\n";
}

sub get_aligned_node {
    my ( $t_node ) = @_;
    my ($aligned, $types) = $t_node->get_aligned_nodes;
    if ( $types ) {
        my $i;
        for ( $i = 0; $i < @{$types}; $i++ ) {
            last if ( $types->[$i] eq "monolingual" );
        }
        return $aligned->[$i];
    }
    return undef;
}

sub get_opposite_links {
    my ( $src_tree, $ref_tree ) = @_;
    my %ref2src_node;
    foreach my $src_node ( $src_tree->get_descendants ) {
        my $ref_node = get_aligned_node($src_node);
        $ref2src_node{$ref_node} = $src_node if ( $ref_node );
    }
    return %ref2src_node;
}

sub test_en_it_linked {
    my ( $gold_tree, $autom_tree ) = @_;
    my %autom2gold_node = get_opposite_links($gold_tree, $autom_tree);
    
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
    foreach my $t_node ( $autom_tree->get_descendants ) {
        my ($a_it) = grep { $_->form =~ /^[iI][tT]$/ } $t_node->get_anodes;
        if ( $a_it ) {
            my $verb;
            if ( $t_node->t_lemma ne "#PersPron" ) {
                $verb = $t_node;
#                 $total_sum++;
            }
            else {
                ($verb) = $t_node->get_eparents( { or_topological => 1} );
            }
            if ( $verb
                and grep { $_->functor eq "ACT"
                    and $_ ne $t_node
                    and not $_->is_generated
                    } $verb->get_echildren( { or_topological => 1} )
                and $a_it->afun eq "Sb"
            ) {
# #                     There is a pleonastic "it"
                $eval_sum++;
#                 print $verb->get_address . "\n";
#                 print $verb->t_lemma . "\n";
#                 print join "\t", map { $_->form } $verb->get_anodes;
#                 print "\n";
#                 print joing "\t", map { $_->t_lemma } $verb->get_echildren;
#                 print "\n";
                my $gold_verb = $autom2gold_node{$verb};
                if ( $gold_verb and grep { $_->form =~ /^[iI][tT]$/ } $gold_verb->get_anodes ) {
                    $correct_sum++;
#                     print $verb->get_address . "\n";
                }
                else {
#                     print $t_node->get_address . "\n";
                }
            }
        }
    }
    print "$correct_sum\t$eval_sum\t$total_sum\n";
}

# process PCEDT 2.0 linked manually and automatically annotated data
sub process_bundle_linked {
    my ( $self, $bundle ) = @_;

    my $gold_cs_tree = $bundle->get_zone('cs', 'ref')->get_ttree;
    my $autom_cs_tree = $bundle->get_zone('cs', 'src')->get_ttree;
    my $gold_en_tree = $bundle->get_zone('en', 'ref')->get_ttree;
    my $autom_en_tree = $bundle->get_zone('en', 'src')->get_ttree;

#     test_cs_it_linked($gold_cs_tree, $autom_cs_tree);
    test_en_it_linked($gold_en_tree, $autom_en_tree);
}

# process PCEDT 2.0 manually annotated data
sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en_tree = $bundle->get_zone('en')->get_ttree;
    my $cs_tree = $bundle->get_zone('cs')->get_ttree;

#     analyze_en($en_tree);
#     analyze_cs($cs_tree);
    test_it_en($en_tree);
#     test_it_cs($cs_tree);
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

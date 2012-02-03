package Treex::Block::Eval::AddPersPronIt;
use Moose;
use Treex::Core::Common;
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

sub test_it_en {
    my ( $en_tree ) = @_;
    foreach my $t_node ( $en_tree->get_descendants ) {
        my ($it) = grep { $_->form =~ /^[iI][tT]$/ } $t_node->get_anodes;
        if ( $it ) {
            my $verb;
            if ( $t_node->t_lemma ne "#PersPron" ) {
                $verb = $t_node;
                $total_sum++;
            }
            else {
                ($verb) = $t_node->get_eparents( { or_topological => 1} );
            }
            if ( $verb
                and grep { $_->functor eq "ACT"
                    and $_ ne $t_node
                    and not $_->is_generated
                } $verb->get_echildren( { or_topological => 1} )
                and $it->afun eq "Sb"
            ) {
#                 if ( grep { $_->functor eq "ACT" and $_ ne $t_node and not $_->is_generated} @verb_echildren
#                 and grep { $_->functor eq "PAT" and $_ ne $t_node } @verb_echildren ) {
# #                     There is a pleonastic "it"
                $eval_sum++;
                if ( $t_node->t_lemma ne "#PersPron" ) {
                    $correct_sum++;
                }
                else {
                    print $t_node->get_address . "\n";
                }
            }
        }
    }
}

# returns 1 if the given node is a reflexive passivum
sub is_refl_pass {
    my ($t_node) = @_;
    foreach my $anode ( $t_node->get_anodes ) {
        return 1 if ( grep { $_->afun eq "AuxR" and $_->form eq "se" } $anode->children );
    }
    return 0;
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
        } $cs_tree->get_descendants
    ) {
#         pleonastic it
        if ( not is_passive_having_PAT($cand_verb)
            and not is_active_having_ACT($cand_verb)
        ) {
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

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $en_tree = $bundle->get_zone('en')->get_ttree;
    my $cs_tree = $bundle->get_zone('cs')->get_ttree;
#     analyze_en($en_tree);
    analyze_cs($cs_tree);
#     test_it_en($en_tree);
# #     my %autom2gold_node;
# #     my $gold_tree = $bundle->get_zone('cs', 'ref')->get_ttree;
# #     my $autom_tree = $bundle->get_zone('cs', 'src')->get_ttree;
# #     foreach my $gold_node ( $gold_tree->get_descendants ) {
# #         my $autom_node = get_aligned_node($gold_node);
# #         $autom2gold_node{$autom_node} = $gold_node if ( $autom_node );
# #     }
#     my @predicted_verbs;
#     $total_sum += get_total_sum($gold_tree);
#     foreach my $cand_verb ( grep {
#             $_->is_clause_head
#             and not is_passive_having_PAT($_)
#             and not is_active_having_ACT($_)
#             and not is_GEN($_)
#             and not is_IMPERS($_)
#             and not has_subject($_)
#         } $autom_tree->get_descendants )
#     {
#         $eval_sum++;
#         push @predicted_verbs, $cand_verb;
#         my $gold_verb = get_aligned_node($cand_verb);
# #         my $gold_verb = $autom2gold_node{$cand_verb};
#         if ( $gold_verb ) {
# #             in golden data are constructions "jsem presvedcen" annotated as "byt"->"presvedceny"; in automatic data as "presvedcit"
#             if ( $gold_verb->gram_sempos =~ /^adj\.denot/ ) {
#                 my ($epar) = $gold_verb->get_eparents( { or_topological => 1 } );
#                 $gold_verb = $epar if ( $epar and $epar->t_lemma eq "být" );
#             }
#             if ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $gold_verb->get_echildren ( { or_topological => 1 } ) ) {
#                 $correct_sum++;
#             }
#             elsif ( is_in_coord($gold_verb) ) {
#             }
#     #         DEBUG TODO Pr. Formed hradi, kdezto nehradi: v gold plati Formed pro oba hradit, v autom jen jednou, podruhe bude PersPron a je to spravne!
#             else {
# #                 print $cand_verb->get_address . "\n";
# #                 print $cand_verb->t_lemma . "\n";
# #                 print "GEN: " . is_GEN($cand_verb) . "\n";
#             }
#         }
#     }
# # #     DEBUG
# #     foreach my $gold_verb ( grep { $_->is_clause_head } $gold_tree->get_descendants ) {
# #         if ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $gold_verb->get_echildren( { or_topological => 1 } ) ) {
# #             my $autom_verb = get_aligned_node($gold_verb);
# #             if ( not grep { $_ eq $autom_verb } @predicted_verbs ) {
# #                 print $gold_verb->get_address . "\n";
# #             }
# #         }
# #     }
#     print "$correct_sum\t$eval_sum\t$total_sum\n";
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

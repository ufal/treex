package Treex::Block::Eval::AddPersPronSb;
use Moose;
use utf8;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $impersonal_verbs = 'jednat_se|pršet|zdát_se|dařit_se|oteplovat_se|ochladit_se|stát_se|záležet';

# returns 1 if the given node is a reflexive passivum
sub is_refl_pass {
    my ($t_node) = @_;
    foreach my $anode ( $t_node->get_anodes ) {
        if ( grep { $_->afun =~ /^Aux[RT]$/ and $_->form eq "se" } $anode->children
            and $t_node->t_lemma !~ /\_se$/ ) {
            return 1;
        }
    }
    return 0;
}

# returns 1 if the given node is a passive verb
sub is_passive {
    my ($t_node) = @_;
    return (  grep { $_->tag =~ /^Vs/ } $t_node->get_anodes
        or is_refl_pass($t_node)
    ) ? 1 : 0;
}

# returns 1 if the given node is an passive verb and has an echild with PAT => possibly has an overt subject
sub is_passive_having_PAT {
    my ( $t_node ) = @_;
#     return ( is_passive($t_node)
# #         and grep { ( ( $_->functor || "" ) eq "PAT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } $t_node->get_echildren( { or_topological => 1 } ))
#         and grep { ($_->functor || "" ) eq "PAT" and not $_->is_generated } $t_node->get_echildren( { or_topological => 1 } ) 
#     ) ? 1 : 0;
    if ( is_passive($t_node) ) {
        my ($pat) = grep { ($_->functor || "" ) eq "PAT" } $t_node->get_echildren( { or_topological => 1 } );
        if ( $pat and ($pat->formeme || "") =~ /^n\:(1|4)/ ) {
#             if ( $pat->get_lex_anode 
#                 and $pat->get_lex_anode->tag =~ /^....1/
#             ) {
                return 1;
#             }
        } 
        elsif ( $pat and ( not $pat->is_generated or $pat->t_lemma eq "#EmpNoun" ) ) {
            return 1;
        }
    }
}

# returns 1 if the given node is an active verb and has an echild with ACT => possibly has an overt subject
sub is_active_having_ACT {
    my ( $t_node ) = @_;
#     return ( not is_passive($t_node)
# #         and grep { ( ( $_->functor || "" ) eq "ACT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } $t_node->get_echildren( { or_topological => 1 } ))
#         and grep { ($_->functor || "" ) eq "ACT" 
#         and not $_->is_generated } $t_node->get_echildren( { or_topological => 1 } ) 
#     ) ? 1 : 0;
    if ( not is_passive($t_node) ) {
#         if ( $t_node->id eq "T-wsj0041-001-p1s20a1" ) {
#             print "a tady\n";
#         }
        my ($act) = grep { ($_->functor || "" ) eq "ACT" } $t_node->get_echildren( { or_topological => 1 } );
        if ( $act and ($act->formeme || "") =~ /^n\:(1|4)/ ) {
            return 1;
#             ($act->gram_sempos || "") =~ /^n\.denot/ ) {
#             if ( $act->get_lex_anode 
#                 and $act->get_lex_anode->tag =~ /^....1/
#             ) {
#                 return 1;
#             }
        } 
        elsif ( $act and ( not $act->is_generated or $act->t_lemma eq "#EmpNoun" ) ) {
            return 1;
        }
    }
}

sub is_byt_videt {
    my ( $t_node ) = @_;
    return ( $t_node->t_lemma eq "být"
        and grep { $_->t_lemma =~ /^(vidět|slyšet|cítit)$/ } $t_node->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

# returns 1 if the given node is lze/byt mozny/byt nutny
sub is_byt_mozny {
    my ( $t_node ) = @_;
    return ( $t_node->t_lemma eq "lze"
        or ( $t_node->t_lemma eq "být"
            and grep { $_->t_lemma =~ /^(možný|nutný)$/ } $t_node->get_echildren( { or_topological => 1 } ) )
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

# returns 1 if the given node has an echild with #Gen as its subject
sub is_GEN {
    my ( $t_node ) = @_;
    return ( is_byt_videt($t_node)
        or is_byt_mozny($t_node)
        or ( has_o_ending($t_node) and not has_neutrum_sibling($t_node) )
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
    return 1 if ( grep { not $_->is_generated and $_->get_lex_anode->afun =~ /^Sb/ } $t_node->get_echildren( { or_topological => 1 } ) );
#     foreach my $child ( grep { not $_->is_generated } $t_node->get_echildren( { or_topological => 1 } ) ) {
#         return 1 if ( $child->get_lex_anode->afun eq "Sb" );
#     }
    foreach my $averb ( grep { $_->tag =~ /^V/ } $t_node->get_anodes ) {
        return 1 if ( grep { $_->afun =~ /^Sb/ } $averb->children );
        my ($acoord) = grep { $_->afun eq "Coord" } $averb->children;
        if ( $acoord ) {
            return 1 if ( grep { $_->afun =~ /^Sb/ } $acoord->children );
        }
    }
    return 0;
}

sub is_clause_head {
    my ( $t_node ) = @_;
    return ( $t_node->get_lex_anode 
        and grep { $_->tag =~ /^V[Bpi]/ } $t_node->get_anodes
    ) ? 1 : 0;
}

# error in adding functor, the predicate of the subject subordinate clause has PAT functor
sub has_sb_clause {
    my ( $t_node ) = @_;
    return ( 
        grep { 
            $_->functor =~ /^(ACT|PAT)$/
            and ($_->gram_sempos || "") eq "v"
            and not $_->is_generated
            and is_clause_head($_)
        } $t_node->get_echildren ( { or_topological => 1 } )
    ) ? 1 : 0;
}

sub has_sb_clause_gold {
    my ( $t_node ) = @_;
    return ( grep { $_->functor eq "ACT"
            and ($_->gram_sempos || "") eq "v"
            and not $_->is_generated
            and is_clause_head($_)
        } $t_node->get_echildren ( { or_topological => 1 } )
    ) ? 1 : 0;
}

# for automatic data
sub has_subject {
    my ( $t_node ) = @_;
#     if ( $t_node->id eq "T-wsj1100-001-p1s0a9" ) {
#         if ( has_subject($cand_verb) ) {
#             print "halo\n";
#         }
#     }
    return ( 
#         grep { ( $_->formeme || "" ) eq "n:1" } $t_node->get_echildren( { or_topological => 1 } )
        has_asubject($t_node)
        or has_sb_clause($t_node)
    ) ? 1 : 0;
}

sub has_subject_gold {
    my ( $t_node ) = @_;
    return (
        has_asubject($t_node)
        or has_sb_clause_gold($t_node)
        or is_active_having_ACT($t_node)
        or is_passive_having_PAT($t_node)
    ) ? 1 : 0;
}

my $correct_sum = 0;
my $eval_sum = 0;
my $total_sum = 0;

sub get_aligned_node {
    my ( $t_node ) = @_;
    my ($aligned, $types) = $t_node->get_directed_aligned_nodes;
    return ( $aligned->[0] ) ? $aligned->[0] : "";
}

sub is_in_coord {
    my ( $t_node ) = @_;
    if ( ($t_node->get_parent->functor || "") eq "CONJ" ) {
        my @siblings = grep { ($_->functor || "") eq $t_node->functor } $t_node->get_siblings;
#         TODO: if sibling->ord < node->ord and node->is_active_having_ACT or is_passive_having_PAT then 1 else 0
    }
}

sub get_total_sum {
    my ( $gold_tree ) = @_;
    my $total_sum = 0;
    foreach my $perspron ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $gold_tree->get_descendants ) {
        my @eparents = grep { ($_->gram_sempos || "" ) eq "v" } $perspron->get_eparents ( { or_topological => 1 } );
        if ( @eparents > 0 ) {
            my $epar = $eparents[0];
            if ( ( $epar->is_clause_head or is_clause_head($epar) )
                and not $epar->is_generated
                and not has_subject($epar)
                and ( ( is_passive($epar) and $perspron->functor eq "PAT" )
                    or ( not is_passive($epar) and $perspron->functor eq "ACT" ) )
                and not grep { $_->t_lemma eq "#Gen" and $_->functor eq "ACT" } $epar->get_echildren ( { or_topological => 1 } )
            ) {
                $total_sum += @eparents;
            }
        }
    }
    return $total_sum;
}

sub has_pleon_sb {
    my ( $t_node ) = @_;
    my @echildren = $t_node->get_echildren( { or_topological => 1 } );
    return ( ( $t_node->is_clause_head or is_clause_head($t_node) )
        and not $t_node->is_generated
        and not has_subject_gold($t_node)
        and (
            not grep { $_->t_lemma eq "#PersPron" and $_->is_generated } @echildren
            or (
                grep { $_->t_lemma eq "#Gen" and $_->functor eq "ACT" } @echildren
                and not ( is_passive($t_node) and grep { $_->t_lemma eq "#PersPron" and $_->is_generated and $_->functor eq "PAT" } @echildren )
            )
        )
    ) ? 1 : 0;
}

sub has_unexpressed_sb {
    my ( $t_node ) = @_;
    my @echildren = $t_node->get_echildren( { or_topological => 1 } );
    foreach my $perspron ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } @echildren ) {
        if ( ( $t_node->is_clause_head or is_clause_head($t_node) )
            and not $t_node->is_generated
            and not has_subject_gold($t_node)
            and (
                ( 
                    is_passive($t_node) 
                    and $perspron->functor eq "PAT" 
                    and not grep { $_->t_lemma eq "#Gen" and $_->functor eq "ACT" } @echildren 
                )
                or ( 
                    not is_passive($t_node) 
                    and $perspron->functor eq "ACT" 
                ) 
#                 or not has_subject_gold($t_node)
#                 or not grep { $_->t_lemma eq "#Gen" and $_->functor eq "ACT" } @echildren
            )
#             and not grep { $_->t_lemma eq "#Gen" and $_->functor eq "ACT" } @echildren
        ) {
            return 1;
        }
    }
    return 0;
}

# the given verb has o-ending and there is a neutrum n.denot in the main clause
sub has_neutrum_sibling {
    my ( $verb ) = @_;
    my ($epar) = $verb->get_eparents ( { or_topological => 1 } );
    if ( $epar and ($epar->formeme || "") =~ /^v:.*fin$/ ) {
#     if ( $epar and ($epar->functor || "") eq "PRED" ) {
        my @echildren_anodes = map { $_->get_anodes } $epar->get_echildren( { or_topological => 1 } );
        if ( grep { $_->tag =~ /^..N/ } @echildren_anodes ) {
            return 1;
        }
    }
    return 0;
}

sub has_o_having_neutrum {
    my ( $verb ) = @_;
    if ( has_o_ending($verb) ) {
        my ($epar) = $verb->get_eparents ( { or_topological => 1 } );
        if ( $epar and ($epar->functor || "") eq "PRED" ) {
            my @echildren_anodes = map { $_->get_anodes } $epar->get_echildren( { or_topological => 1 } );
            if ( grep { $_->tag =~ /^..N/ } @echildren_anodes ) {
                return 1;
            }
        }
    }
    return 0;
}

# returns 1 if the given candidate verb - clause head will be given a generated #PersPron node as an unexpressed subject
sub will_have_perspron_gold {
    my ( $cand_verb ) = @_;
#     if ( has_o_having_neutrum($cand_verb) ) {
#         print $cand_verb->get_address . "\n";
#     }
    return (
        not is_passive_having_PAT($cand_verb)
        and not is_active_having_ACT($cand_verb)
        and not is_GEN($cand_verb)
        and not is_IMPERS($cand_verb)
#        and not has_subject_gold($cand_verb)
#         and not has_o_having_neutrum($cand_verb)
    ) ? 1 : 0;
}

# returns 1 if the given candidate verb - clause head will be given a generated #PersPron node as an unexpressed subject
sub will_have_perspron {
    my ( $cand_verb ) = @_;
#     if ( has_o_having_neutrum($cand_verb) ) {
#         print $cand_verb->get_address . "\n";
#     }
    return (
        not is_passive_having_PAT($cand_verb)
        and not is_active_having_ACT($cand_verb)
        and not is_GEN($cand_verb)
        and not is_IMPERS($cand_verb)
        and not has_subject($cand_verb)
#         and not has_o_having_neutrum($cand_verb)
    ) ? 1 : 0;
}

sub will_have_pleon_gold {
    my ( $cand_verb ) = @_;
    return (
        not has_subject_gold($cand_verb)
        and not is_passive_having_PAT($cand_verb)
        and not is_active_having_ACT($cand_verb)
        and (
            is_GEN($cand_verb)
            or is_IMPERS($cand_verb)
        )
    ) ? 1 : 0;
}

sub will_have_pleon {
    my ( $cand_verb ) = @_;
    return (
        not has_subject($cand_verb)
        and not is_passive_having_PAT($cand_verb)
        and not is_active_having_ACT($cand_verb)
        and (
            is_GEN($cand_verb)
            or is_IMPERS($cand_verb)
        )
    ) ? 1 : 0;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my %autom2gold_node;
    my $gold_tree = $bundle->get_zone('cs')->get_ttree;
    my $autom_tree = $bundle->get_zone('cs', 'autom')->get_ttree;
#     my $gold_tree = $bundle->get_zone('cs', 'ref')->get_ttree;
#     my $autom_tree = $bundle->get_zone('cs', 'src')->get_ttree;
#     foreach my $gold_node ( $gold_tree->get_descendants ) {
#         my $autom_node = get_aligned_node($gold_node);
#         $autom2gold_node{$autom_node} = $gold_node if ( $autom_node );
#     }
    my @predicted_verbs;
    $total_sum += get_total_sum($gold_tree);
    foreach my $cand_verb ( grep {
            $_->is_clause_head
            and not is_passive_having_PAT($_)
            and not is_active_having_ACT($_)
            and not is_GEN($_)
            and not is_IMPERS($_)
            and not has_subject($_)
        } $autom_tree->get_descendants )
    {
        $eval_sum++;
        push @predicted_verbs, $cand_verb;
        my $gold_verb = get_aligned_node($cand_verb);
#         my $gold_verb = $autom2gold_node{$cand_verb};
        if ( $gold_verb ) {
#             in golden data are constructions "jsem presvedcen" annotated as "byt"->"presvedceny"; in automatic data as "presvedcit"
            if ( $gold_verb->gram_sempos =~ /^adj\.denot/ ) {
                my ($epar) = $gold_verb->get_eparents( { or_topological => 1 } );
                $gold_verb = $epar if ( $epar and $epar->t_lemma eq "být" );
            }
            if ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $gold_verb->get_echildren ( { or_topological => 1 } ) ) {
                $correct_sum++;
            }
            elsif ( is_in_coord($gold_verb) ) {
            }
    #         DEBUG TODO Pr. Formed hradi, kdezto nehradi: v gold plati Formed pro oba hradit, v autom jen jednou, podruhe bude PersPron a je to spravne!
            else {
#                 print $cand_verb->get_address . "\n";
#                 print $cand_verb->t_lemma . "\n";
#                 print "GEN: " . is_GEN($cand_verb) . "\n";
            }
        }
    }
# #     DEBUG
#     foreach my $gold_verb ( grep { $_->is_clause_head } $gold_tree->get_descendants ) {
#         if ( grep { $_->t_lemma eq "#PersPron" and $_->is_generated } $gold_verb->get_echildren( { or_topological => 1 } ) ) {
#             my $autom_verb = get_aligned_node($gold_verb);
#             if ( not grep { $_ eq $autom_verb } @predicted_verbs ) {
#                 print $gold_verb->get_address . "\n";
#             }
#         }
#     }
    print "$correct_sum\t$eval_sum\t$total_sum\n";
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Eval::AddPersPronSb

=head1 DESCRIPTION

Testing adding new Czech nodes with t_lemma #PersPron corresponding to unexpressed ('prodropped') subjects of finite clauses.

=head1 AUTHORS

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

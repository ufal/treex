package Treex::Block::Eval::AddPersPronSb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $impersonal_verbs = 'jednat_se|pršet|zdát_se|dařit_se|oteplovat_se|ochladit_se';

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
sub is_passive_having_PAT {
    my ( $t_node ) = @_;
    return ( is_passive($t_node)
#         and grep { ( ( $_->functor || "" ) eq "PAT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } $t_node->get_echildren( { or_topological => 1 } ))
        and grep { ($_->functor || "" ) eq "PAT" and not $_->is_generated } $t_node->get_echildren( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

# returns 1 if the given node is an active verb and has an echild with ACT => possibly has an overt subject
sub is_active_having_ACT {
    my ( $t_node ) = @_;
    return ( not is_passive($t_node)
#         and grep { ( ( $_->functor || "" ) eq "ACT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } $t_node->get_echildren( { or_topological => 1 } ))
        and grep { ($_->functor || "" ) eq "ACT" and not $_->is_generated } $t_node->get_echildren( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

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

sub has_sb {
    my ( $t_node ) = @_;
    return ( grep { ( $_->formeme || "" ) =~ /^(n:1|n:subj)$/ } $t_node->get_echildren( { or_topological => 1 } )
    ) ? 1 : 0;
}

my $correct_sum;
my $eval_sum;
my $total_sum;

sub get_aligned_node {
    my ( $t_node ) = @_;
    my ($aligned, $types) = $t_node->get_aligned_nodes;
    return ( $aligned->[0] ) ? $aligned->[0] : "";
}

sub is_in_coord {
    my ( $t_node ) = @_;
    if ( ($t_node->get_parent->functor || "") eq "CONJ" ) {
        my @siblings = grep { ($_->functor || "") eq $t_node->functor } $t_node->get_siblings;
#         TODO: if sibling->ord < node->ord and node->is_active_having_ACT or is_passive_having_PAT then 1 else 0
    }
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my %autom2gold_node;
    my $gold_tree = $bundle->get_zone('cs', 'ref')->get_ttree;
    my $autom_tree = $bundle->get_zone('cs', 'src')->get_ttree;
    foreach my $gold_node ( $gold_tree->get_descendants ) {
        my $autom_node = get_aligned_node($gold_node);
        $autom2gold_node{$autom_node} = $gold_node if ( $autom_node );
    }
    my @predicted_verbs;
    foreach my $cand_verb ( grep {
            $_->is_clause_head
            and not is_passive_having_PAT($_)
            and not is_active_having_ACT($_)
            and not is_GEN($_)
            and not is_IMPERS($_)
            and not has_sb($_)
        } $autom_tree->get_descendants )
    {
        $eval_sum++;
        push @predicted_verbs, $cand_verb;
        my $gold_verb = $autom2gold_node{$cand_verb};
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
    #         DEBUG
            else {
                print $cand_verb->get_address . "\n";
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

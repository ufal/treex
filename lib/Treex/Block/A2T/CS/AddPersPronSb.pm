package Treex::Block::A2T::CS::AddPersPronSb;
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
        and grep { ($_->functor || "" ) eq "PAT" } $t_node->get_echildren( { or_topological => 1 } ) 
    ) ? 1 : 0;
}

# returns 1 if the given node is an active verb and has an echild with ACT => possibly has an overt subject
sub is_active_having_ACT {
    my ( $t_node ) = @_;
    return ( not is_passive($t_node)
#         and grep { ( ( $_->functor || "" ) eq "ACT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } $t_node->get_echildren( { or_topological => 1 } ))
        and grep { ($_->functor || "" ) eq "ACT" } $t_node->get_echildren( { or_topological => 1 } ) 
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
    return ( $t_node->get_lex_anode and $t_node->get_lex_anode->form =~ /o$/ 
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

sub process_tnode_final {
    my ( $self, $t_node ) = @_;

#     if ( $t_node->is_clause_head
#         && !grep { ( ( $_->functor || "" ) eq "ACT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } $t_node->get_echildren( { or_topological => 1 } )
#         )
#     {
    if ( $t_node->is_clause_head
        and not is_passive_having_PAT($t_node)
        and not is_active_having_ACT($t_node)
        and not is_GEN($t_node)
        and not is_IMPERS($t_node)
#         TODO: budu se spolehat na n:1 (subst v nominativu) a n:subj (subst je subjekt)???
        )
    {

#         # There is an auxiliary reflexive
#         if ( my $auxr = first { my $a = $_->get_lex_anode(); $a and $a->afun eq 'AuxR' }
#                  $t_node->get_echildren( { or_topological => 1 } ) ){
# 
#             $auxr->set_functor('ACT');
#             $auxr->set_formeme('drop');
# 
#             $auxr->set_gram_gender('neut');
#             $auxr->set_gram_person('3');
#             $auxr->set_gram_number('sg');
#             return;
#         }                    
                
        my $new_node = $t_node->create_child;
        $new_node->set_t_lemma('#PersPron');
        $new_node->set_functor('ACT');
        $new_node->set_formeme('drop');

        #$new_node->set_attr( 'ord',     $t_node->get_attr('ord') - 0.1 );
        #$new_node->set_id($t_node->generate_new_id );
        $new_node->set_nodetype('complex');
        $new_node->set_gram_sempos('n.pron.def.pers');
        $new_node->set_is_generated(1);
        $new_node->shift_before_node($t_node);

        my @anode_tags = map { $_->tag } ( $t_node->get_lex_anode, $t_node->get_aux_anodes );

        my ( $person, $gender, $number );

        if ( grep { $_ =~ /^(V.|J,).....1/ } @anode_tags ) { # include 'kdybychom', 'abychom'
            $person = "1";
        }
        elsif ( grep { $_ =~ /^(V.|J,).....2/ } @anode_tags ) { # include 'kdybys(te)', 'abys(te)'
            $person = "2";
        }
        else {
            $person = "3";
        }

        if ( grep { $_ =~ /^V..P/ } @anode_tags ) {
            $number = 'pl';
        }
        else {
            $number = 'sg';
        }

        if ( grep { $_ =~ /^V.Q/ } @anode_tags ) {    # napraseno !!! ve skutecnosti je poznani rodu daleko tezsi
            $gender = 'fem';
        }
        elsif ( grep { $_ =~ /^V.N/ } @anode_tags ) {
            $gender = 'neut';
        }
        # evidence from the data - gender of the generated perspron can be anything, 
        # if the verb is in present tense and 1st or 2nd person
        elsif ( grep {$_ =~ /^VB-.---[12]P.*/} @anode_tags ) {
            $gender = 'nr';
        }
        else {
            $gender = 'anim';
        }
# TODO         where is $gender = 'inan'???

        $new_node->set_gram_person($person);
        $new_node->set_gram_gender($gender);
        $new_node->set_gram_number($number);
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::AddPersPronSb

=head1 DESCRIPTION

New Czech nodes with t_lemma #PersPron corresponding to unexpressed ('prodropped') subjects of finite clauses
are added.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

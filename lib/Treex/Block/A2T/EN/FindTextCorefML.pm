package Treex::Block::A2T::EN::FindTextCorefML;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $language = 'en';
my $selector = 'ref';
my $range = 10;

my $modal_adjs = 'possible|clear|certain|definite|probable|important|imperative|necessary|useful|easy|hard';
my $to_clause_verbs = 'be|s|become|make|take';
my $to_clause_verbs_pat = 'make|take';
my $be_verbs = 'be|s|become';
my $cog_ed_verbs = 'think|believe|recommend|say|note|expect';
my $cog_verbs = 'seem|appear|mean|follow|matter';

my $actant_ls = '(ACT|PAT|ADDR|APP)';

sub get_cands {
    my ( $anaph ) = @_;
    
    # current sentence
    my @precendants = grep { $_->precedes($anaph) }
        $anaph->get_root->get_descendants( { ordered => 1 } );

    # previous sentences
    my $sent_num = $anaph->get_bundle->get_position;

    if ( $sent_num > 0 ) {
        my $bottom_idx = $sent_num - $range;
        $bottom_idx = 0 if ($bottom_idx < 0);
        my $top_idx = $sent_num - 1;
        my @all_bundles = $anaph->get_document->get_bundles;
        my @prev_bundles = @all_bundles[ $bottom_idx .. $top_idx ];
        my @prev_ttrees   = map {
            $_->get_zone($language, $selector)->get_ttree
        } @prev_bundles;
        unshift @precendants, map { $_->get_descendants( { ordered => 1 } ) } @prev_ttrees;
    }
    
    my @antecs = $anaph->get_coref_text_nodes;
    my ($pos_cand, @neg_cands);
    foreach my $prec ( reverse @precendants ) {
        if ( ( $prec->gram_sempos || "" ) =~ /^n/ 
            and ( !$prec->gram_person || ($prec->gram_person !~ /(1|2)/) ) 
            and not grep { $_ eq $prec } @antecs
        ) {
            push @neg_cands, $prec;
        }
        $pos_cand = $prec if ( not $pos_cand and grep { $_ eq $prec } @antecs );
    }
    $pos_cand = $anaph if ( not $pos_cand );
    
    return ($pos_cand, @neg_cands);
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

sub get_coref_features {
    my ($cand, $anaph) = @_;
    my %coref_features = ();
    my @feat_names = qw(
        c_cand_fun         c_anaph_fun           b_fun_agree               c_join_fun
        c_cand_afun        c_anaph_afun          b_afun_agree              c_join_afun
        b_cand_akt         b_anaph_akt           b_akt_agree 
        b_cand_subj        b_anaph_subj          b_subj_agree
       
        c_cand_gen         c_anaph_gen           b_gen_agree               c_join_gen
        c_cand_num         c_anaph_num           b_num_agree               c_join_num
        c_cand_atag        c_anaph_atag          b_atag_agree              c_join_atag
       
        c_sempos_agree     c_join_sempos
       c_formeme_agree    c_join_formeme
        c_alemma_agree     c_join_alemma

        c_cand_epar_sempos c_anaph_epar_sempos   b_epar_sempos_agree       c_join_epar_sempos
                                                b_epar_lemma_agree        c_join_epar_lemma
                                                                          c_join_clemma_aeparlemma
        b_is_pleon
        b_its_verb_has_v_to_inf
        b_its_verb_has_v_to_inf_err
        b_its_verb_is_be_adj
        b_its_verb_is_be_adj_err
        b_its_verb_is_cog_verb
        b_its_verb_is_cog_ed_verb_err
        
        
    );

#                 if ( $verb
#                     and ( has_v_to_inf($verb)
#                         or is_be_adj($verb)
#                         or is_cog_verb($verb)
# #                         or has_v_to_inf_err($t_node, $autom_tree)
#                         or is_be_adj_err($verb)
#                         or is_cog_ed_verb_err($verb)
#                         or has_cs_to($verb, $en2cs_node{$t_node})
#                     ) 
#                 ) {
    
    return (\%coref_features, \@feat_names);
}

sub process_document {
    my ( $self, $document ) = @_;
    
    my @all_ttrees = map {
        $_->get_zone($language, $selector)->get_ttree
    } $document->get_bundles;
    
#     all (third person) semantic nouns 
#     my @semnouns = 
#         grep { 
#             ( $_->gram_sempos || "" ) =~ /^n/ 
#             and ( !$_->gram_person || ($_->gram_person !~ /(1|2)/) ) 
#         } map { $_->get_descendants( { ordered => 1 } ) } @all_ttrees;

#     foreach my $ttree ( @all_ttrees ) {
#         push @semnouns, grep { ( $_->gram_sempos || "" ) =~ /^n/ and ( !$_->gram_person || ($_->gram_person !~ /(1|2)/) ) } $ttree->get_descendants( { ordered => 1 } );
#     }

#     print join "\t", map { $_->t_lemma } ($semnouns[0], $semnouns[1], $semnouns[2], $semnouns[3], $semnouns[4], $semnouns[5], $semnouns[6], $semnouns[7], $semnouns[8], $semnouns[9]);
#     print "\n\n";

    foreach my $anaph ( grep { $_->t_lemma eq "#PersPron" and $_->gram_person !~ /(1|2)/} map { $_->get_descendants } @all_ttrees ) {
#         my $antec = $anaph->get_coref_text_nodes->[0];
        my ( $pos_cand, @neg_cands ) = get_cands($anaph);
        if ( $pos_cand ) {
            # Positive candidate
            my ($pfeatures, $pfeat_names) = get_coref_features($pos_cand, $anaph, $pos_cand->{cand_ord}, \%np_freq, \%collocation);
            print_coref_features($pfeatures, $pfeat_names, 1, $anaph->{id});
            # Negative candidates
            CANDIDATE:
            for my $neg_cand ( @neg_cands ) {
                my ($pfeatures, $pfeat_names) = get_coref_features($neg_cand, $anaph, $neg_cand->{cand_ord}, \%np_freq, \%collocation);
                print_coref_features($pfeatures, $pfeat_names, 0, $anaph->{id});
            }
        }
#         my @antecs = $anaph->get_coref_text_nodes;
#         my @ante_cands = get_ante_cands($anaph);
#         if ( grep { $_ eq $antecs[0] } @ante_cands ) {
# #             print possitive instance
#             foreach my $cand ( @ante_cands ) {
#                 next if ( $cand eq $antecs[0] );
# #                 print negative instances
#             }
#         }
#         if ( grep { $_ eq $anaph } ($semnouns[0], $semnouns[1], $semnouns[2], $semnouns[3], $semnouns[4], $semnouns[5], $semnouns[6], $semnouns[7], $semnouns[8], $semnouns[9]) ) {
#             print $anaph->get_address . "\n";
#             print "antecedent:\t" . $antecs[0]->id . "\n";
#             print join "\t", map { $_->id } @ante_cands;
#             print "\n\n";
#         }
    }
    
#     foreach my $ttree ( @all_ttrees ) {
#         foreach my $perspron ( grep { $_->t_lemma eq "#PersPron" } $ttree->get_descendants )
#     }
    
#     print $semnouns[9]->get_address . "\n";
}

sub process_ttree_heuristic {
# sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @semnouns = grep { ( $_->gram_sempos || "" ) =~ /^n/ } $t_root->get_descendants( { ordered => 1 } );

    foreach my $perspron ( grep { $_->t_lemma eq "#PersPron" and $_->formeme =~ /poss/ and $_->nodetype eq 'complex' } $t_root->get_descendants ) {

        my %attrib = map { ( $_ => $perspron->get_attr("gram/$_") ) } qw(gender number person);

        my @candidates = reverse grep { $_->precedes($perspron) } @semnouns;

        # pruning by required agreement in number
        @candidates = grep { ( $_->gram_number || "" ) eq $attrib{number} } @candidates;

        # pruning by required agreement in person
        if ( $attrib{person} =~ /[12]/ ) {
            @candidates = grep { ( $_->gram_person || "" ) eq $attrib{person} } @candidates;
        }
        else {
            @candidates = grep { ( $_->gram_person || "" ) !~ /[12]/ } @candidates;
        }

        #	print "Sentence:\t".$bundle->get_attr('english_source_sentence')."\t";
        #	print "Anaphor:\t".$perspron->get_lex_anode->form."\t";

        if ( my $antec = $candidates[0] ) {

            #	    print "YES: ".$antec->t_lemma."\n";
            $perspron->set_deref_attr( 'coref_text.rf', [$antec] );

        }
        else {

            #	    print "NO";
        }

    }
    return 1;

}

1;

=over

=item Treex::Block::A2T::EN::FindTextCorefML

Machine learning approach for finding textual coreference links.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky, Nguy Giang Linh, Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

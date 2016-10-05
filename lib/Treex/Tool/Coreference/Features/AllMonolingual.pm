package Treex::Tool::Coreference::Features::AllMonolingual;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter;
use Data::Printer;
use List::MoreUtils qw/any/;

extends 'Treex::Tool::Coreference::BaseCorefFeatures';

my $UNDEF_VALUE = "undef";
my $b_true = 1;
my $b_false = 0;

########################## MAIN METHODS ####################################

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    return if (($type ne 'cand') && ($type ne 'anaph'));

    my $feats = {};
    $feats->{id} = $node->get_address;

    my @nodetypes = Treex::Tool::Coreference::NodeFilter::get_types($node);
    $feats->{'t^type'} = \@nodetypes;

    $self->morphosyntax_unary_feats($feats, $node, $type);
    $self->location_feats($feats, $node, $type);    
    
    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

override '_binary_features' => sub {
    my ($self, $set_feats, $anaph, $cand, $candord) = @_;

    my $feats = {};
    $self->distance_feats($feats, $set_feats, $anaph, $cand, $candord);
    $self->morphosyntax_binary_feats($feats, $set_feats, $anaph, $cand);
    return $feats;
};


################## LOCATION AND DISTANCE FEATURES ####################################

sub location_feats {
    my ($self, $feats, $node, $type) = @_;
    if ($type eq 'anaph') {
        $feats->{sentord} = $self->_categorize( $node->get_root->wild->{czeng_sentord}, [0, 1, 2, 3] );
        # a feature from (Charniak and Elsner, 2009)
        $feats->{charniak_loc} = $self->_anaph_loc_buck($node);
    }
}

sub distance_feats {
    my ($self, $feats, $set_feats, $anaph, $cand, $candord) = @_;
    $feats->{sent_dist} = $anaph->get_bundle->get_position - $cand->get_bundle->get_position;
    $feats->{clause_dist} = $self->_categorize( $anaph->wild->{aca_clausenum} - $cand->wild->{aca_clausenum}, [-2, -1, 0, 1, 2, 3, 7] );
    $feats->{deepord_dist} = $self->_categorize( $anaph->wild->{doc_ord} - $cand->wild->{doc_ord}, [1, 2, 3, 6, 15, 25, 40, 50] );
    $feats->{cand_ord} = $self->_categorize( $candord, [1, 2, 3, 5, 8, 11, 17, 22] );
    # a feature from (Charniak and Elsner, 2009)
    $feats->{charniak_dist} = $self->_ante_loc_buck($anaph, $cand, $feats->{sent_dist});
}

sub _anaph_loc_buck {
    my ($self, $anaph) = @_;
    return $self->_categorize( $anaph->ord, [0, 3, 5, 9] );
}

sub _ante_loc_buck {
    my ($self, $anaph, $cand, $sent_dist) = @_;

    my $pos = $cand->ord;
    if ($sent_dist == 0) {
        $pos = $anaph->ord - $cand->ord;
    }
    return $self->_categorize( $pos, [0, 3, 5, 9, 17, 33] );
}

################## MORPHO-(DEEP)SYNTAX FEATURES ####################################

my %actants = map { $_ => 1 } qw/ACT PAT ADDR APP/;

sub morphosyntax_unary_feats {
    my ($self, $feats, $node, $type) = @_;
    
    my $anode = $node->get_lex_anode;
    $feats->{lemma} = defined $anode ? $anode->lemma : $UNDEF_VALUE;
    $feats->{afun}  = defined $anode ? $anode->afun : $UNDEF_VALUE;
    
    $feats->{tlemma} = $node->t_lemma;
    $feats->{fmm}  = $node->formeme;
    $feats->{fun}  = $node->functor;
    $feats->{akt}  = $actants{ $node->functor } ? $b_true : $b_false;
    $feats->{subj}  = _is_subject($node);
    $feats->{coord} = ( $node->is_member ) ? $b_true : $b_false if ($type eq 'cand');
    $feats->{pers} = $node->is_name_of_person ? $b_true : $b_false;
    _set_eparent_features($feats, $node, $type);

    # features copied from the extractor for relative pronouns
    # grammatemes
    $feats->{gen} = $node->gram_gender || $UNDEF_VALUE;
    $feats->{num} = $node->gram_number || $UNDEF_VALUE;
    for my $gen (qw/anim inan fem neut/) {
        $feats->{"gen_$gen"} = $feats->{gen} =~ /$gen/ ? 1 : 0;
    }

    # features copied from the extractor for reflexive pronouns
    $feats->{is_refl} = Treex::Tool::Coreference::NodeFilter::matches($node, ['reflpron']) ? 1 : 0 if ($type eq 'cand');
    $feats->{is_subj_for_refl}  = $self->_is_subject_for_refl($node) if ($type eq 'cand');

    # features focused on demonstrative pronouns
    if ($type eq 'anaph') {
        $feats->{is_neutsg} = ($feats->{gen_neut} && $feats->{num} =~ /sg/) ? 1 : 0;
        $feats->{has_relclause} = _is_extended_by_relclause($node) ? 1 : 0;
        $feats->{has_clause} = (any {($_->clause_number // 0) != ($node->clause_number // 0)} $node->get_echildren) ? 1 : 0;
        $feats->{kid_fmm} = [ grep {defined $_} map {$_->formeme} $node->get_echildren ];
        $feats->{fmm_epar_lemma} = ($feats->{epar_lemma} // "undef") . '_' . ($feats->{fmm} // "undef");
    }
}

sub morphosyntax_binary_feats {
    my ($self, $feats, $set_feats, $anaph, $cand) = @_;

    # TODO: all join_ features can be possibly left out since VW does it automatically if -q ac is on
    my @names = qw/
        apos anum afun fmm
        fun akt subj
        gen num
        epar_fmm
        epar_lemma epar_sempos epar_fun
    /;
    foreach my $name (@names) {
        $feats->{"agree_$name"} = $self->_agree_feats($set_feats->{"c^cand_$name"}, $set_feats->{"a^anaph_$name"});
        $feats->{"join_$name"} = $self->_join_feats($set_feats->{"c^cand_$name"}, $set_feats->{"a^anaph_$name"});
    }
    $feats->{agree_gennum} = $self->_agree_feats($feats->{agree_gen}, $feats->{agree_num});
    $feats->{join_gennum} = $self->_join_feats($feats->{agree_gen}, $feats->{agree_num});
    $feats->{join_clemma_aeparlemma} = $self->_join_feats($cand->t_lemma, $set_feats->{'a^anaph_epar_lemma'});
    
    $feats->{app_in_coord} = _is_app_in_coord( $cand, $anaph );
    $feats->{sibl} = _are_siblings( $cand, $anaph );
    
    # features copied from the extractor for relative pronouns
    $feats->{clause_parent} = $self->_is_clause_parent($anaph, $cand) ? 1 : 0;
    $feats->{cand_ancestor} = (any {$_ == $anaph} $cand->get_descendants()) ? 1 : 0;
    $feats->{cand_ancestor_num_agree} = $feats->{cand_ancestor} . "_" . $feats->{agree_num};
    $feats->{cand_ancestor_gen_agree} = $feats->{cand_ancestor} . "_" . $feats->{agree_gen};
    $feats->{cand_ancestor_gennum_agree} = $feats->{cand_ancestor} . "_" . $feats->{agree_gen} . "_" . $feats->{agree_num};
    
    my $aanaph = $anaph->get_lex_anode;
    my $acand = $cand->get_lex_anode;
    if (defined $aanaph && defined $acand) {
        my @anodes = $aanaph->get_root->get_descendants({ordered => 1});
        my @nodes_between = @anodes[$acand->ord .. $aanaph->ord-2];
        
        $feats->{is_comma_between} = any {$_->form eq ","} @nodes_between;
        $feats->{words_between_count} = scalar @nodes_between;
    }

    # features copied from the extractor for reflexive pronouns
    $feats->{clause_subject} = $self->_is_clause_subject($anaph, $cand) ? 1 : 0;
    $feats->{in_clause} = $anaph->clause_number eq $cand->clause_number ? 1 : 0;
    $feats->{refl_in_clause} = $set_feats->{'c^cand_is_refl'} . "_" . $feats->{in_clause};
    
    # features focused on demonstrative pronouns
    $feats->{join_neutsg_num} = $self->_join_feats(
        $set_feats->{'a^anaph_is_neutsg'},
        $feats->{agree_num},
    );
    $feats->{join_neutsg_gennum} = $self->_join_feats(
        $set_feats->{'a^anaph_is_neutsg'},
        $feats->{agree_gennum},
    );
}

# TODO: investigate what is goin on in all the following methods
sub _is_subject {
	my ($node) = @_;
	my $par = ($node->get_eparents({or_topological => 1}))[0];
    return $b_false if (!defined $par || $par->is_root);
	
    if ($par->gram_tense && ($par->gram_tense =~ /^(sim|ant|post)/) || 
        ($par->functor eq 'DENOM')) {
		
        my @cands = $par->get_echildren({or_topological => 1});
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

sub _is_subject_for_refl {
    my ($self, $t_node) = @_;
    return ($t_node->formeme // '') =~ /^(n:1|n:subj|drop)$/;
}

# returns the first eparent's functor, sempos, formeme, lemma, diathesis,
# and its diathesis combined with the candidate's functor
sub _set_eparent_features {
	my ($feats, $node, $type) = @_;
	my ($epar) = $node->get_eparents({or_topological => 1});
    return if (!$epar);

    $feats->{epar_fun} = $epar->functor;
    $feats->{epar_sempos} = $epar->gram_sempos;
    $feats->{epar_fmm} = $epar->formeme;
    $feats->{epar_lemma} = $epar->t_lemma;
    $feats->{epar_diath} = $epar->gram_diathesis // "0";
    $feats->{fun_epar_diath} = $feats->{epar_diath} . "_" . $feats->{fun};
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

# returns if $inode and $jnode have the same eparent
sub _are_siblings {
	my ($inode, $jnode) = @_;
	my $ipar = ($inode->get_eparents({or_topological => 1}))[0];
	my $jpar = ($jnode->get_eparents({or_topological => 1}))[0];
	return ($ipar == $jpar) ? $b_true : $b_false;
}

# this is a simplified version of what is in Block::A2T::MarkRelClauseCoref
sub _is_clause_parent {
    my ($self, $anaph, $cand) = @_;
    my $clause = $anaph->get_clause_head;
    return 0 if ($clause->is_root);
    my @parents = $clause->get_eparents( { or_topological => 1 } );
    return any {$_ == $cand} @parents;
}

# this is a simplified version of what is in Block::A2T::MarkReflpronCoref
sub _is_clause_subject {
    my ($self, $anaph, $cand) = @_;
    my $clause = $anaph->get_clause_head;
    return 0 if ($clause->is_root);
    my ($clause_subj) = grep {$self->_is_subject_for_refl($_)} $clause->get_echildren( { or_topological => 1 } );
    return (defined $clause_subj) && ($clause_subj == $cand);
}

# aims at demonstrative pronouns followed by a relative (or seems-to-be-relative) clause
sub _is_extended_by_relclause {
    my ($anaph) = @_;
    my @relclause_heads = $anaph->get_echildren;
    my ($first_relclause_node) = sort {$a->ord <=> $b->ord} map {$_->get_descendants} @relclause_heads;
    return 0 if (!defined $first_relclause_node);
    return Treex::Tool::Coreference::NodeFilter::matches($first_relclause_node, ['relpron']);
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::Features::AllMonolingual

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

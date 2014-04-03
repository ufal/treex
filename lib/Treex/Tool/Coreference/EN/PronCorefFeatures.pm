package Treex::Tool::Coreference::EN::PronCorefFeatures;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);

extends 'Treex::Tool::Coreference::PronCorefFeatures';

my $b_true = '1';
my $b_false = '-1';

my %actants2 = map { $_ => 1 } qw/ACT PAT ADDR EFF ORIG/;

has 'ewn_classes_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 
        'data/models/coreference/EN/features/noun_to_ewn_top_ontology.tsv',
);

has '_ewn_classes' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef[ArrayRef[Str]]',
    lazy        => 1,
    builder     => '_build_ewn_classes',
);

has 'tag_properties' => (
    is => 'ro',
    isa => 'HashRef[HashRef[Maybe[Str]]]',
    builder => '_build_tag_properties',
    required => 1,
);

has 'ne_properties' => (
    is => 'ro',
    isa => 'HashRef[HashRef[Maybe[Str]]]',
    builder => '_build_ne_properties',
    required => 1,
);

sub BUILD {
    my ($self) = @_;

    $self->_ewn_classes;
    #$self->_build_feature_names;
}

sub _build_tag_properties {
    my ($self) = @_;

    my $tag_properties = {
        CC => { pos => 'J', subpos => undef, number => undef, gender => undef},  # Coordinating conjunction
        CD => { pos => 'C', subpos => undef, number => undef, gender => undef},  # Cardinal number
        DT => { pos => 'Det', subpos => undef, number => undef, gender => undef},  # Determiner
        EX => { pos => 'X', subpos => undef, number => undef, gender => undef},  # Existential there
        FW => { pos => 'X', subpos => undef, number => undef, gender => undef},  # Foreign word
        IN => { pos => 'R', subpos => undef, number => undef, gender => undef},  # Preposition or subordinating conjunction
        JJ => { pos => 'A', subpos => undef, number => undef, gender => undef},  # Adjective
        JJR => { pos => 'A', subpos => undef, number => undef, gender => undef},     # Adjective, comparative
        JJS => { pos => 'A', subpos => undef, number => undef, gender => undef},     # Adjective, superlative
        LS => { pos => 'X', subpos => undef, number => undef, gender => undef},  # List item marker
        MD => { pos => 'V', subpos => undef, number => undef, gender => undef},  # Modal
        NN => { pos => 'N', subpos => undef, number => 'S', gender => undef},  # Noun, singular or mass
        NNS => { pos => 'N', subpos => undef, number => 'P', gender => undef},     # Noun, plural
        NNP => { pos => 'N', subpos => undef, number => 'S', gender => undef},     # Proper noun, singular
        NNPS => { pos => 'N', subpos => undef, number => 'P', gender => undef},    # Proper noun, plural
        PDT => { pos => 'Det', subpos => undef, number => undef, gender => undef},     # Predeterminer
        POS => { pos => 'P', subpos => undef, number => undef, gender => undef},     # Possessive ending
        PRP => { pos => 'P', subpos => undef, number => undef, gender => undef},     # Personal pronoun
        'PRP$' => { pos => 'P', subpos => undef, number => undef, gender => undef},    # Possessive pronoun
        RB => { pos => 'D', subpos => undef, number => undef, gender => undef},  # Adverb
        RBR => { pos => 'D', subpos => undef, number => undef, gender => undef},     # Adverb, comparative
        RBS => { pos => 'D', subpos => undef, number => undef, gender => undef},     # Adverb, superlative
        RP => { pos => 'T', subpos => undef, number => undef, gender => undef},  # Particle
        SYM => { pos => 'X', subpos => undef, number => undef, gender => undef},     # Symbol
        TO => { pos => 'X', subpos => undef, number => undef, gender => undef},  # to
        UH => { pos => 'I', subpos => undef, number => undef, gender => undef},  # Interjection
        VB => { pos => 'V', subpos => undef, number => undef, gender => undef},  # Verb, base form
        VBD => { pos => 'V', subpos => undef, number => undef, gender => undef},     # Verb, past tense
        VBG => { pos => 'V', subpos => undef, number => undef, gender => undef},     # Verb, gerund or present participle
        VBN => { pos => 'V', subpos => undef, number => undef, gender => undef},     # Verb, past participle
        VBP => { pos => 'V', subpos => undef, number => undef, gender => undef},     # Verb, non-3rd person singular present
        VBZ => { pos => 'V', subpos => undef, number => undef, gender => undef},     # Verb, 3rd person singular present
        WDT => { pos => 'Det', subpos => undef, number => undef, gender => undef},     # Wh-determiner
        WP => { pos => 'P', subpos => undef, number => undef, gender => undef},  # Wh-pronoun
        WP => { pos => 'P', subpos => undef, number => undef, gender => undef},     # Possessive wh-pronoun
        WRB => { pos => 'D', subpos => undef, number => undef, gender => undef},     # Wh-adverb 
    };
    return $tag_properties;
}

sub _build_ne_properties {
    my ($self) = @_;

    my $ne_properties = {
        i_ => { cat => 'i_', subcat => undef},  # Organization
        g_ => { cat => 'g_', subcat => undef},  # Location
        P  => { cat => 'P', subcat => undef},  # Person
        PM => { cat => 'P', subcat => 'M'},  # Person masculinum
        PF => { cat => 'P', subcat => 'F'},  # Person femininum
        pf => { cat => 'p', subcat => 'f'},  # Person's first name
        ps => { cat => 'p', subcat => 's'},  # Person's surname
    };
    return $ne_properties;
}

#sub _build_feature_names {
#    my ($self) = @_;
#
#    # TODO filter out the features not used here
#    my @feat_names = qw(
#       c_sent_dist        c_clause_dist         c_file_deepord_dist
#       c_cand_ord         c_anaph_sentord
#       
#       c_cand_fmm         c_anaph_fmm           b_fmm_agree               c_join_fmm
#       c_cand_fun         c_anaph_fun           b_fun_agree               c_join_fun
#       c_cand_afun        c_anaph_afun          b_afun_agree              c_join_afun
#       b_cand_akt         b_anaph_akt           b_akt_agree 
#       b_cand_subj        b_anaph_subj          b_subj_agree
#       
#       c_cand_gen         c_anaph_gen           b_gen_agree               c_join_gen
#       c_cand_num         c_anaph_num           b_num_agree               c_join_num
#       c_cand_atag        c_anaph_atag          b_atag_agree              c_join_atag
#       c_cand_apos        c_anaph_apos          b_apos_agree              c_join_apos
#       c_cand_anum        c_anaph_anum          b_anum_agree              c_join_anum
#       
#       b_cand_coord       b_app_in_coord
#       c_cand_epar_fun    c_anaph_epar_fun      b_epar_fun_agree          c_join_epar_fun
#       c_cand_epar_fmm    c_anaph_epar_fmm      b_epar_fmm_agree          c_join_epar_fmm
#       c_cand_epar_sempos c_anaph_epar_sempos   b_epar_sempos_agree       c_join_epar_sempos
#                                                b_epar_lemma_agree        c_join_epar_lemma
#                                                                          c_join_clemma_aeparlemma
#
#       b_sibl             b_coll                
#       r_cand_freq                            
#       b_cand_pers
#
#       c_cand_loc_buck    c_anaph_loc_buck
#       c_cand_type        c_anaph_type
#       c_cand_synttype    
#       
#       c_cand_ne_cat      c_cand_ne_subcat
#
#    );
#    
#    # EuroWordNet nouns
#     my ($noun_c, $all_c) = map {$self->_ewn_classes->{$_}} qw/nouns all/;
#     foreach my $class (sort @{$all_c}) {
#         my $coref_class = "b_" . $class;
#         push @feat_names, $coref_class;
#     }
#    
#    return \@feat_names;
#}

sub _get_pos {
    my ($self, $node) = @_;
    my $tag = $self->_get_atag( $node );
    return undef if (!defined $tag);

    my $prop = $self->tag_properties->{$tag};
    return undef if (!defined $prop);

    return $prop->{pos};
}

sub _get_ne {
    my ($self, $t_node) = @_;
    my $n_node = $t_node->get_n_node();

    if ( $n_node ) {
        my $type = $n_node->get_attr('ne_type');
        my $prop = $self->ne_properties->{$type};
        return ($prop->{"cat"}, $prop->{"subcat"});
    }
    
    return ("", "");
}

sub _get_number {
    my ($self, $node) = @_;
    my $tag = $self->_get_atag( $node );
    return undef if (!defined $tag);

    my $prop = $self->tag_properties->{$tag};
    return undef if (!defined $prop);

    return $prop->{number};
}

sub _get_atag {
	my ($self, $node) = @_;
	my $anode = $node->get_lex_anode;
    if ($anode) {
		return $anode->tag;
	}
    return;
}

sub _ante_synt_type {
    my ($self, $cand) = @_;
    my @anodes_prep = grep {my $tag = $self->_get_pos($cand); defined $tag && ($tag eq 'R')} $cand->get_aux_anodes;

    if (@anodes_prep > 0) {
        return 'prep';
    }
    my $anode = $cand->get_lex_anode;
    if ($anode->afun eq 'Sb') {
        return 'sb';
    }
    if ($anode->afun eq 'Obj') {
        return 'obj';
    }
    return 'oth';
}

sub _ante_type {
    my ($self, $cand) = @_;

    if (defined $cand->get_n_node) {
        return 'ne';
    }
    my $pos = $self->_get_pos($cand);
    if (defined $pos && ($pos eq 'N')) {
        return 'noun';
    }
    if (defined $pos && ($pos eq 'P')) {
        return 'pronoun';
    }
    return 'oth';
}

sub _anaph_type {
    my ($self, $anaph) = @_;

    my $anode = $anaph->get_lex_anode;
    if ($anode->tag eq 'PRP$') {
        return 'poss';
    }
    if ($anode->tag eq 'PRP') {
        if ($anode->form =~ /.+sel(f|ves)$/) {
            return 'refl';
        }
        if ($anode->afun eq 'Obj') {
            return 'obj';
        }
        if ($anode->afun eq 'Sb') {
            return 'sb';
        }
    }
    return 'oth';
}

sub _build_ewn_classes {
    my ($self) = @_;

    my $ewn_file = require_file_from_share( $self->ewn_classes_path, ref($self) );
    log_fatal 'File ' . $ewn_file . 
        ' with an EuroWordNet onthology for English used' .
        ' in pronominal textual coreference resolution does not exist.' 
        if !-f $ewn_file;
    open EWN, "<:utf8", $ewn_file;
    
    my $ewn_classes = {};
    while (my $line = <EWN>) {
        chomp $line;
        my ($noun, $classes_string) = split /\t/, $line;
        my (@classes) = split / /, $classes_string;
        $ewn_classes->{$noun} = \@classes;
    }
    close EWN;

    return $ewn_classes;
}

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;
    my $coref_features = super();

    $coref_features->{b_gen_agree} 
        = $self->_agree_feats($set_features->{c_cand_gen}, $set_features->{c_anaph_gen});
    $coref_features->{c_join_gen} 
        = $self->_join_feats($set_features->{c_cand_gen}, $set_features->{c_anaph_gen});

    $coref_features->{b_num_agree} 
        = $self->_agree_feats($set_features->{c_cand_num}, $set_features->{c_anaph_num});
    $coref_features->{c_join_num} 
        = $self->_join_feats($set_features->{c_cand_num}, $set_features->{c_anaph_num});

    $coref_features->{b_atag_agree} 
        = $self->_agree_feats($set_features->{c_cand_atag}, $set_features->{c_anaph_atag});
    $coref_features->{c_join_atag}  
        = $self->_join_feats($set_features->{c_cand_atag}, $set_features->{c_anaph_atag});

    $coref_features->{b_apos_agree} 
        = $self->_agree_feats($set_features->{c_cand_apos}, $set_features->{c_anaph_apos});
    $coref_features->{c_join_apos}  
        = $self->_join_feats($set_features->{c_cand_apos}, $set_features->{c_anaph_apos});

    $coref_features->{b_anum_agree} 
        = $self->_agree_feats($set_features->{c_cand_anum}, $set_features->{c_anaph_anum});
    $coref_features->{c_join_anum}  
        = $self->_join_feats($set_features->{c_cand_anum}, $set_features->{c_anaph_anum});

    return $coref_features;
};

override '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    my $coref_features = super();
    
    $coref_features->{'c_'.$type.'_gen'} = $node->gram_gender;
    $coref_features->{'c_'.$type.'_num'} = $node->gram_number;
    
    $coref_features->{'c_'.$type.'_atag'} = $self->_get_atag( $node );
    $coref_features->{'c_'.$type.'_apos'} = $self->_get_pos( $node );
    $coref_features->{'c_'.$type.'_anum'} = $self->_get_number( $node );

    if ( $type eq 'cand' ) {
        ( $coref_features->{'c_'.$type.'_ne_cat'}, $coref_features->{'c_'.$type.'_ne_subcat'} )
            = $self->_get_ne($node);
    }
    
    # features from (Charniak and Elsner, 2009)
    if ($type eq 'anaph') {
        $coref_features->{'c_'.$type.'_type'} = $self->_anaph_type( $node );
    }
    elsif ($type eq 'cand') {
        $coref_features->{'c_'.$type.'_type'} = $self->_ante_type( $node );
        $coref_features->{'c_'.$type.'_synttype'} = $self->_ante_synt_type( $node );
    }

###########################
    #   Semantic:
    #   1:  is_name_of_person
    if ($type eq 'cand') {
        $coref_features->{b_cand_pers} =  $node->is_name_of_person ? $b_true : $b_false;

        #   EuroWordNet nouns
        $coref_features->{cand_ewn_class} = $self->_ewn_classes->{$node->t_lemma};
    }
    
    if ($type eq 'anaph') {
        $coref_features->{'b_'.$type.'_referential'} = $node->wild->{referential};
    }
    
    return $coref_features;
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::EN::PronCorefFeatures

=head1 DESCRIPTION

Features needed in English personal pronoun coreference resolution.

=head1 PARAMETERS

=over

=item feature_names

Names of features that should be used for training/resolution.
See L<Treex::Tool::Coreference::CorefFeatures> for more info.

=back

=head1 METHODS

=over

=item _build_feature_names 

Builds a list of features required for training/resolution.

=item _unary_features

It returns a hash of unary features that relate either to the anaphor or the
antecedent candidate.

Enriched with language-specific features.

=item _binary_features 

It returns a hash of binary features that combine both the anaphor and the
antecedent candidate.

Enriched with language-specific features.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

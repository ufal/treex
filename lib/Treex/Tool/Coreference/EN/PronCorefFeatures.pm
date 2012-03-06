package Treex::Tool::Coreference::EN::PronCorefFeatures;

use Moose;
use Treex::Core::Common;

extends 'Treex::Tool::Coreference::PronCorefFeatures';

has 'tag_properties' => (
    is => 'ro',
    isa => 'HashRef[HashRef[Maybe[Str]]]',
    builder => '_build_tag_properties',
    required => 1,
);

sub BUILD {
    my ($self) = @_;

    $self->_build_feature_names;
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

sub _build_feature_names {
    my ($self) = @_;

    my @feat_names = qw(
       c_sent_dist        c_clause_dist         c_file_deepord_dist
       c_cand_ord         c_anaph_sentord
       
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
    
    return \@feat_names;
}

sub _get_pos {
    my ($self, $node) = @_;
    my $tag = $self->_get_atag( $node );
    return undef if (!defined $tag);

    my $prop = $self->tag_properties->{$tag};
    return undef if (!defined $prop);

    return $prop->{pos};
}
sub _get_number {
    my ($self, $node) = @_;
    my $tag = $self->_get_atag( $node );
    return undef if (!defined $tag);

    my $prop = $self->tag_properties->{$tag};
    return undef if (!defined $prop);

    return $prop->{number};
}
sub _get_gender {
    my ($tag) = @_;
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
    my @anodes_prep = grep {$self->_get_pos($cand) eq 'R'} $cand->get_aux_anodes;

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
    my $anode = $cand->get_lex_anode;
    if ($self->_get_pos($anode) eq 'N') {
        return 'noun';
    }
    if ($self->_get_pos($anode) eq 'P') {
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

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;
    my $coref_features = super();

    $coref_features->{c_join_atag}  
        = $self->_join_feats($set_features->{c_cand_atag}, $set_features->{c_anaph_atag});
    $coref_features->{c_join_apos}  
        = $self->_join_feats($set_features->{c_cand_apos}, $set_features->{c_anaph_apos});
    $coref_features->{c_join_anum}  
        = $self->_join_feats($set_features->{c_cand_anum}, $set_features->{c_anaph_anum});
    
    return $coref_features;
};

override '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    my $coref_features = super();

    $coref_features->{'c_'.$type.'_atag'} = $self->_get_atag( $node );
    $coref_features->{'c_'.$type.'_apos'} = $self->_get_pos( $node );
    $coref_features->{'c_'.$type.'_anum'} = $self->_get_number( $node );
    
    return $coref_features;
};

1;

# Copyright 2008-2011 Nguy Giang Linh, Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

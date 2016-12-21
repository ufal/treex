package Treex::Tool::Coreference::Features::EN::AllMonolingual;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);

extends 'Treex::Tool::Coreference::Features::AllMonolingual';

my $UNDEF_VALUE = "undef";
my $b_true = 1;
my $b_false = 0;

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

########################## BUILDERS ####################################

sub BUILD {
    my ($self) = @_;

    $self->_ewn_classes;
    #$self->_build_feature_names;
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

########################## MAIN METHODS ####################################

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    my $feats = {};
    $self->en_morphosyntax_unary_feats($feats, $node, $type);
    $self->en_lexicon_unary_feats($feats, $node, $type);
    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

override '_binary_features' => sub {
    my ($self, $set_feats, $anaph, $cand, $candord) = @_;
    my $feats = super();
    $self->en_morphosyntax_binary_feats($feats, $set_feats, $anaph, $cand, $candord);
    return $feats;
};

################## MORPHO-(DEEP)SYNTAX FEATURES ####################################

sub en_morphosyntax_unary_feats {
    my ($self, $feats, $node, $type) = @_;
	
    my ($tag, $pos, $num) = $self->_get_tag_pos_num($node);
    $feats->{atag} = $tag // $UNDEF_VALUE;
    $feats->{apos} = $pos // $UNDEF_VALUE;
    $feats->{anum} = $num // $UNDEF_VALUE;
    
    # features from (Charniak and Elsner, 2009)
    if ($type eq 'anaph') {
        $feats->{type} = $self->_anaph_type( $node );
    }
    elsif ($type eq 'cand') {
        $feats->{type} = $self->_ante_type( $node );
        $feats->{synttype} = $self->_ante_synt_type( $node );
    }
}

sub en_morphosyntax_binary_feats {
    my ($self, $feats, $set_feats, $anaph, $cand) = @_;
    # TODO: all join_ features can be possibly left out since VW does it automatically if -q ac is on
    my @names = qw/
        atag apos anum
    /;
    foreach my $name (@names) {
        $feats->{"agree_$name"} = $self->_agree_feats($set_feats->{"c^cand_$name"}, $set_feats->{"a^anaph_$name"});
        $feats->{"join_$name"} = $self->_join_feats($set_feats->{"c^cand_$name"}, $set_feats->{"a^anaph_$name"});
    }
}

sub _get_tag_pos_num {
    my ($self, $tnode) = @_;
    my $anode = $tnode->get_lex_anode;
    return if (!defined $anode);
    my $tag = $anode->tag;
    return if (!defined $tag);
    my $prop = $self->tag_properties->{$tag};
    return if (!defined $prop);
    return ($tag, $prop->{pos}, $prop->{number});
}

sub _ante_synt_type {
    my ($self, $cand, $pos) = @_;
    my @anodes_prep = grep {my ($tag, $pos, $num) = $self->_get_tag_pos_num($cand); defined $pos && ($pos eq 'R')} $cand->get_aux_anodes;

    if (@anodes_prep > 0) {
        return 'prep';
    }
    my $anode = $cand->get_lex_anode;
    if (!defined $anode) {
        return 'oth';
    }
    if ($anode->afun eq 'Sb') {
        return 'sb';
    }
    if ($anode->afun eq 'Obj') {
        return 'obj';
    }
    return 'oth';
}

sub _ante_type {
    my ($self, $cand, $pos) = @_;

    if (defined $cand->get_n_node) {
        return 'ne';
    }
    my ($tag, $pos, $num) = $self->_get_tag_pos_num($cand);
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
    if (!defined $anode) {
        return 'oth';
    }
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

############################# LEXICON FEATURES ####################################

sub en_lexicon_unary_feats {
    my ($self, $feats, $node, $type) = @_;
    if ( $type eq 'cand' ) {
        ( $feats->{ne_cat}, $feats->{ne_subcat} ) = $self->_get_ne($node);
        $feats->{ewn_class} = $self->_ewn_classes->{$node->t_lemma};
    }
    if ($type eq 'anaph') {
        $feats->{'referential'} = $node->wild->{referential};
    }
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



1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::Features::EN::AllMonolingual

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

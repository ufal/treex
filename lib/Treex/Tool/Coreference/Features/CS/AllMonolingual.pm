package Treex::Tool::Coreference::Features::CS::AllMonolingual;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use List::MoreUtils qw/all any/;
use Treex::Tool::Vallex::ValencyFrame;

use Ufal::MorphoDiTa;

extends 'Treex::Tool::Coreference::Features::AllMonolingual';

my $UNDEF_VALUE = "undef";
my $b_true = 1;
my $b_false = 0;

my %actants2 = map { $_ => 1 } qw/ACT PAT ADDR EFF ORIG/;

my %a_to_t_genders = (
    '-' => [ 'undef' ],
    'F' => [ 'fem' ],
    'H' => [ 'fem', 'neut' ],
    'I' => [ 'inan' ],
    'M' => [ 'anim' ],
    'N' => [ 'neut' ],
    'Q' => [ 'fem', 'neut' ],
    'T' => [ 'inan', 'fem' ],
    'X' => [ 'inan', 'anim', 'fem', 'neut' ],
    'Y' => [ 'inan', 'anim' ],
    'Z' => [ 'inan', 'anim', 'neut' ],
);

has 'cnk_freqs_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 
        'data/models/coreference/CS/features/cnk_nv_freq.txt',
);

has 'ewn_classes_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',
    default     => 
        'data/models/coreference/CS/features/noun_to_ewn_top_ontology.tsv',
);

has '_cnk_freqs' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef',
    lazy        => 1,
    builder     => '_build_cnk_freqs',
);

has '_ewn_classes' => (
    is          => 'ro',
    required    => 1,
    isa         => 'HashRef[ArrayRef[Str]]',
    lazy        => 1,
    builder     => '_build_ewn_classes',
);

has '_collocations' => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[Str]]'
);

has '_np_freq' => (
    is      => 'rw',
    isa     => 'HashRef[Int]'
);

has '_morpho' => (
    is => 'rw',
    isa => 'Ufal::MorphoDiTa::Morpho',
    builder => '_build_morpho',
);

########################## BUILDERS ####################################

# Attributes _cnk_freqs and _ewn_classes depend on attributes cnk_freqs_path
# and ewn_classes_path, whose values do not have to be accessible when
# building other attributes. Thus, _cnk_freqs and _ewn_classes are defined as
# lazy, i.e. they are built during their first access. However, we wish all
# models to be loaded while initializing a block. Following hack ensures it.
# For an analogous reason feature_names are accessed here as well. 
sub BUILD {
    my ($self) = @_;

    $self->_cnk_freqs;
    $self->_ewn_classes;
#    $self->_build_feature_names;
}

sub _build_cnk_freqs {
    my ($self) = @_;
    
    my $cnk_file = require_file_from_share( $self->cnk_freqs_path, ref($self) );
    log_fatal 'File ' . $cnk_file . 
        ' with a CNK model used for a feature' .
        ' in pronominal textual coreference resolution does not exist.' 
        if !-f $cnk_file;
    open CNK, "<:utf8", $cnk_file;
    
    my $nv_freq;
    my $v_freq;
    
    while (my $line = <CNK>) {
        chomp $line;
        next if ($line =~ /^být/);  # slovesa modální - muset, chtít, moci, směti, mít
        my ($verb, $noun, $freq)= split "\t", $line;
        next if ($freq < 2);

        $v_freq->{$verb} += $freq;
        $nv_freq->{$noun}{$verb} = $freq;
    }
    close CNK;
    
    my $cnk_freqs = { v => $v_freq, nv => $nv_freq };
    return $cnk_freqs;
}

sub _build_ewn_classes {
    my ($self) = @_;

    my $ewn_file = require_file_from_share( $self->ewn_classes_path, ref($self) );
    log_fatal 'File ' . $ewn_file . 
        ' with an EuroWordNet onthology for Czech used' .
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

sub _build_morpho {
    my ($self) = @_;
    my $morpho_path = require_file_from_share( "data/models/morphodita/cs/czech-morfflex-131112.dict", ref($self) );
    log_fatal 'MorphoDiTa model ' . $morpho_path . 'does not exist.' if !-f $morpho_path;
    return Ufal::MorphoDiTa::Morpho::load($morpho_path);
}

########################## MAIN METHODS ####################################

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    
    my $feats = {};
    $self->cs_morphosyntax_unary_feats($feats, $node, $type);
    $self->cs_lexicon_unary_feats($feats, $node, $type);

    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

override '_binary_features' => sub {
    my ($self, $set_feats, $anaph, $cand, $candord) = @_;
    my $feats = super();
    
    $self->cs_morphosyntax_binary_feats($feats, $set_feats, $anaph, $cand, $candord);
    $self->cs_lexicon_binary_feats($feats, $set_feats, $anaph, $cand, $candord);
    return $feats;
};

override 'init_doc_features_from_trees' => sub {
    my ($self, $trees) = @_;
    super();
    
    $self->count_collocations( $trees );
    $self->count_np_freq( $trees );
};


################## MORPHO-(DEEP)SYNTAX FEATURES ####################################

sub cs_morphosyntax_unary_feats {
    my ($self, $feats, $node, $type) = @_;
	
    my $anode = $node->get_lex_anode;
    my @names = qw/
        apos asubpos agen anum acase apossgen apossnum apers
    /;
    for (my $i = 0; $i < 8; $i++) {
        $feats->{$names[$i]} = defined $anode ? substr($anode->tag, $i, 1) : $UNDEF_VALUE;
    }
    $feats->{lemma} = defined $anode ? Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma) : $UNDEF_VALUE;

    # feats for demonstrative pronouns
    if ($type eq "anaph") {
        $feats->{allgens} = defined $anode ? $self->all_possible_genders($anode->form) : $UNDEF_VALUE;
        $feats->{is_a_to} = _is_a_to($anode) ? 1 : 0;
    }
}

sub cs_morphosyntax_binary_feats {
    my ($self, $feats, $set_feats, $anaph, $cand, $candord) = @_;
    my @names = qw/
        apos asubpos agen anum acase apossgen apossnum apers
    /;
    foreach my $name (@names) {
        $feats->{"agree_$name"} = $self->_agree_feats($set_feats->{"c^cand_$name"}, $set_feats->{"a^anaph_$name"});
        $feats->{"join_$name"} = $self->_join_feats($set_feats->{"c^cand_$name"}, $set_feats->{"a^anaph_$name"});
    }
    $feats->{agree_allgens} = $self->_agree_feats($set_feats->{"c^cand_gen"}, $set_feats->{"a^anaph_allgens"});
    $feats->{join_allgens} = $self->_join_feats($set_feats->{"c^cand_gen"}, $set_feats->{"a^anaph_allgens"});
}

sub all_possible_genders {
    my ($self, $form) = @_;
    my $tagged_lemmas = Ufal::MorphoDiTa::TaggedLemmas->new();
    $self->_morpho->analyze($form, 1, $tagged_lemmas);
    my @possible_pron_tags = grep {$_ =~ /^P/} map {my $tl = $tagged_lemmas->get($_); $tl->{tag}} 0 .. $tagged_lemmas->size()-1;
    my %a_gen_tags = map {substr($_,2,1) => 1} @possible_pron_tags;
    my %t_gen_tags = map {$_ => 1} map {@{$a_to_t_genders{$_}}} keys %a_gen_tags;
    return join "|", sort keys %t_gen_tags;
}

sub _is_a_to {
    my ($anode) = @_;
    return if (!defined $anode);
    my $prev_anode = $anode->get_prev_node;
    return if (!defined $prev_anode);
    return ($prev_anode->form eq "a") && ($anode->form eq "to");
}


############################# LEXICON FEATURES ####################################

sub cs_lexicon_unary_feats {
    my ($self, $feats, $node, $type) = @_;
    
    $feats->{freq} = $self->_np_freq->{ $node->t_lemma } || 0 if ($type eq 'cand');
    $feats->{ewn_class} = $self->_ewn_classes->{$node->t_lemma} if ($type eq 'cand');
    
    $self->_valency_for_prodrops($node, $feats, $type) if ($type eq 'anaph');
    $feats->{can_be_nom} = $self->_can_be_nominative($node) ? $b_true : $b_false;
}

sub cs_lexicon_binary_feats {
    my ($self, $feats, $set_feats, $anaph, $cand, $candord) = @_;
    #   1: collocation
    $feats->{coll} = $self->_in_collocation( $cand, $anaph );
    #   1: collocation from CNK
    # TODO this feature should be quantized
    $feats->{cnk_coll} = $self->_in_cnk_collocation( $cand, $anaph );
}

sub _valency_for_prodrops {
    my ($self, $node, $feats, $type) = @_;

    return if (!$node->is_generated);
    return if ($node->functor ne "ACT");

    my ($par) = grep {$_->formeme =~ /^v/} $node->get_eparents;
    return if (!$par);
    
    my $val = $par->get_attr("val_frame.rf");
    return if (!defined $val);
    $val =~ s/^[^\#]*\#//;

    my $frame = Treex::Tool::Vallex::ValencyFrame::get_frame_by_id("vallex-pcedt2.0.xml", $node->language, $val);
    return if (!$frame);
    
    my @siblings = $node->get_siblings;

    if ($self->_sibling_possibly_nominative($node, @siblings)) {
        $feats->{nom_sibling} = $b_true;
        $feats->{nom_sibling_epar_lemma} = $b_true . '_' . $par->t_lemma;
    }
    $feats->{too_many_acc} = $b_true if (_too_many_acc_among_siblings($node, $frame, @siblings));
    if ($feats->{too_many_acc} && $feats->{nom_sibling}) {
        $feats->{too_many_acc_nom_sibling} = $b_true;
        $feats->{too_many_acc_nom_sibling_epar_lemma} = $b_true .'_'. $par->t_lemma;
    }
    if (_nominative_refused_by_valency($node, $frame, @siblings)) {
        $feats->{nom_refused} = $b_true;
        $feats->{nom_refused_epar_lemma} = $b_true .'_'. $par->t_lemma;
    }
}

sub _sibling_possibly_nominative {
    my ($self, $node, @siblings) = @_;
    return any {$_->formeme =~ /^n:4$/ && $self->_can_be_nominative($_)} @siblings;
}

sub _too_many_acc_among_siblings {
    my ($node, $frame, @siblings) = @_;
    my $elements = $frame->elements_have_form("n:4");

    my @acc_nodes = grep {$_->formeme =~ /^n:4$/} @siblings;

    return (scalar(@$elements) < scalar(@acc_nodes));
}

sub _nominative_refused_by_valency {
    my ($node, $frame, @siblings) = @_;
    
    my %siblings_forms = map {$_->formeme => 1} @siblings;
    
    my $elements = $frame->elements_have_form("n:1");
    return all {
        any {$siblings_forms{$_}} @{$_->forms_list}
    } @$elements;
}

# nominative is sometimes mislabeled as accusative, which results in generating a superfluous #PersPron
# use MorphoDiTa morpho analyzer to let the model know that this may happen
sub _can_be_nominative {
    my ($self, $tnode) = @_;

    my $anode = $tnode->get_lex_anode;
    return if (!defined $anode);

    return if ($anode->tag !~ /^....4/);

    my $tagged_lemmas = Ufal::MorphoDiTa::TaggedLemmas->new();
    $self->_morpho->analyze($anode->form, 1, $tagged_lemmas);
    my @possible_tags = map {my $tl = $tagged_lemmas->get($_); $tl->{tag}} 0 .. $tagged_lemmas->size()-1;
    return any {$_ =~ /^....1/} @possible_tags;
}

# return if $inode and $jnode have the same collocation
sub _in_collocation {
	my ($self, $inode, $jnode) = @_;
    my $collocation = $self->_collocations;
	foreach my $jpar ($jnode->get_eparents({or_topological => 1})) {
		if ($jpar->gram_sempos && ($jpar->gram_sempos =~ /^v/) && !$jpar->is_generated) {
			my $jcoll = $jnode->functor . "-" . $jpar->t_lemma;
			my $coll_list = $collocation->{$jcoll};
			if (() = grep {$_ eq $inode->t_lemma} @{$coll_list}) {
				return $b_true;
			}
		}
	}
	return $b_false;
}

# return if $inode and $jnode have the same collocation in CNK corpus
sub _in_cnk_collocation {
    my ($self, $inode, $jnode) = @_;
    foreach my $jpar ($jnode->get_eparents({or_topological => 1})) {
        if ($jpar->gram_sempos && ($jpar->gram_sempos =~ /^v/) && !$jpar->is_generated) {
            my ($v_freq, $nv_freq) = map {$self->_cnk_freqs->{$_}} qw/v nv/;

            my $nv_sum = $nv_freq->{$inode->t_lemma}{$jpar->t_lemma};
            my $v_sum = $v_freq->{$jpar->t_lemma};
            if ($v_sum && $nv_sum) {
                return $nv_sum / $v_sum;
            }
        }
    }
    return 0;
}

sub count_collocations {
    my ( $self, $trees ) = @_;
    my ( $collocation ) = {};
    
    foreach my $tree (@{$trees}) {
        foreach my $node ( $tree->descendants ) {

            if ($node->gram_sempos && ( $node->gram_sempos =~ /^v/ ) && !$node->is_generated ) {
                
                foreach my $child ( $node->get_echildren({or_topological => 1}) ) {
                    
                    if ( $child->functor && $actants2{ $child->functor } && 
                        $child->gram_sempos && ( $child->gram_sempos =~ /^n\.denot/ )) {
                        
                        my $key = $child->functor . "-" . $node->t_lemma;
                        push @{ $collocation->{$key} }, $child->t_lemma;
                    }
                }
            }
        }
    }
    $self->_set_collocations( $collocation );
}

sub count_np_freq {
    my ( $self, $trees ) = @_;
    my $np_freq  = {};

    foreach my $tree (@{$trees}) {
        foreach my $node ( $tree->descendants ) {
            
            if ($node->gram_sempos && ($node->gram_sempos =~ /^n\.denot/ ) 
                && (!$node->gram_person || ( $node->gram_person !~ /1|2/ ))) {
                    
                    $np_freq->{ $node->t_lemma }++;
            }
        }
    }
    $self->_set_np_freq( $np_freq );
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::CS::PronCorefFeatures

=head1 DESCRIPTION

Features needed in Czech personal pronoun coreference resolution.

=head1 PARAMETERS

=over

#=item feature_names
#
#Names of features that should be used for training/resolution.
#See L<Treex::Tool::Coreference::CorefFeatures> for more info.

=item cnk_freqs_path

Path to frequencies of noun-verb bindings extracted from Czech National
Corpus (CNK).

=item ewn_classes_path

Path to ontology of nouns extracted from Euro WordNet (EWN).

=back

=head1 METHODS

=over

#=item _build_feature_names 
#
#Builds a list of features required for training/resolution.

=item _unary_features

It returns a hash of unary features that relate either to the anaphor or the
antecedent candidate.

Enriched with language-specific features.

=item _binary_features 

It returns a hash of binary features that combine both the anaphor and the
antecedent candidate.

Enriched with language-specific features.

=item init_doc_features_from_trees

A place to initialize and precompute the data necessary for 
document-scope (actually having just the scope of all t-trees from
a correpsonding zone) features.

Prepares collocations and frequencies within the whole document.
# TODO this almost certainly isn't a language-specific feature

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Nguy Giang Linh <linh@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

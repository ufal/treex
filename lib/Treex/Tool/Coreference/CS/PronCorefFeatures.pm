package Treex::Tool::Coreference::CS::PronCorefFeatures;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use List::MoreUtils qw/all any/;
use Treex::Tool::Vallex::ValencyFrame;

use Ufal::MorphoDiTa;

extends 'Treex::Tool::Coreference::PronCorefFeatures';

my $b_true = '1';
my $b_false = '-1';

my %actants2 = map { $_ => 1 } qw/ACT PAT ADDR EFF ORIG/;

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

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;
    my $coref_features = super();

###########################
    #   Morphological:
    #   8:  gender, num, agreement, joined
    
    $coref_features->{b_gen_agree} 
        = $self->_agree_feats($set_features->{'c^c_cand_gen'}, $set_features->{'a^c_anaph_gen'});
    $coref_features->{c_join_gen} 
        = $self->_join_feats($set_features->{'c^c_cand_gen'}, $set_features->{'a^c_anaph_gen'});

    $coref_features->{b_num_agree} 
        = $self->_agree_feats($set_features->{'c^c_cand_num'}, $set_features->{'a^c_anaph_num'});
    $coref_features->{c_join_num} 
        = $self->_join_feats($set_features->{'c^c_cand_num'}, $set_features->{'a^c_anaph_num'});

    $coref_features->{c_join_asubpos}  
        = $self->_join_feats($set_features->{'c^c_cand_asubpos'}, $set_features->{'a^c_anaph_asubpos'});
    $coref_features->{c_join_agen}  
        = $self->_join_feats($set_features->{'c^c_cand_agen'}, $set_features->{'a^c_anaph_agen'});
    $coref_features->{c_join_acase}  
        = $self->_join_feats($set_features->{'c^c_cand_acase'}, $set_features->{'a^c_anaph_acase'});
    $coref_features->{c_join_apossgen}  
        = $self->_join_feats($set_features->{'c^c_cand_apossgen'}, $set_features->{'a^c_anaph_apossgen'});
    $coref_features->{c_join_apossnum}  
        = $self->_join_feats($set_features->{'c^c_cand_apossnum'}, $set_features->{'a^c_anaph_apossnum'});
    $coref_features->{c_join_apers}  
        = $self->_join_feats($set_features->{'c^c_cand_apers'}, $set_features->{'a^c_anaph_apers'});
    #   1: collocation
    $coref_features->{b_coll} = $self->_in_collocation( $cand, $anaph );

    #   1: collocation from CNK
    # TODO this feature should be quantized
    $coref_features->{r_cnk_coll} = $self->_in_cnk_collocation( $cand, $anaph );

    return $coref_features;
};

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    my $coref_features = {};

###########################
    #   Morphological:
    #   8:  gender, num, agreement, joined

    if ($type eq 'cand') {
        ( $coref_features->{c_cand_gen}, $coref_features->{c_cand_num} ) = _get_cand_gennum( $node );
        #print STDERR "UNDEF: " . $node->get_address ."\n" if (!defined $coref_features->{c_cand_gen});
    }
    else {
        $coref_features->{c_anaph_gen} = $node->gram_gender;
        $coref_features->{c_anaph_num} = $node->gram_number;
    }
    for my $gen (qw/anim inan fem neut/) {
        $coref_features->{'c_'.$type.'_gen_'.$gen} = (defined $coref_features->{'c_'.$type.'_gen'} && $coref_features->{'c_'.$type.'_gen'} =~ /$gen/) || 0;
    }

    #   24: 8 x tag($inode, $jnode), joined
    $coref_features->{'c_'.$type.'_apos'}  = _get_atag( $node,  0 );
    $coref_features->{'c_'.$type.'_asubpos'}  = _get_atag( $node,  1 );
    $coref_features->{'c_'.$type.'_agen'}  = _get_atag( $node,  2 );
    $coref_features->{'c_'.$type.'_anum'}  = _get_atag( $node,  3 );
    $coref_features->{'c_'.$type.'_acase'}  = _get_atag( $node,  4 );
    $coref_features->{'c_'.$type.'_apossgen'}  = _get_atag( $node,  5 );
    $coref_features->{'c_'.$type.'_apossnum'}  = _get_atag( $node,  6 );
    $coref_features->{'c_'.$type.'_apers'}  = _get_atag( $node,  7 );
    #   1:  freq($inode);
    #    $coref_features->{cand_freq} = ($$np_freq{$cand->{t_lemma}} > 1) ? $b_true : $b_false;
    
    if ($type eq 'cand') {
        $coref_features->{r_cand_freq} = $self->_np_freq->{ $node->t_lemma } || 0;
    }
    
    $coref_features->{$type.'_can_be_nom'} = $self->_can_be_nominative($node) ? $b_true : $b_false;
    if ($type eq 'anaph') {
        $self->_valency_for_prodrops($node, $coref_features, $type);
    }

###########################
    #   Semantic:
    #   1:  is_name_of_person
    if ($type eq 'cand') {
        $coref_features->{b_cand_pers} =  $node->is_name_of_person ? $b_true : $b_false;

        #   EuroWordNet nouns
        $coref_features->{cand_ewn_class} = $self->_ewn_classes->{$node->t_lemma};
    }

    my $sub_feats = inner() || {};
    return { %$coref_features, %$sub_feats };
};

### returns the final gender and number of a list of coordinated nodes: Tata a mama sli; Mama a dite sly
sub _get_coord_gennum {
	my ($parray, $node) = @_;
	my $antec = ($node->get_coref_gram_nodes)[0];

    my ($gen, $num);

# TODO temporary hack
    if (@{$parray} < 1) {
        return ('inan','sg');
    }

	if ((scalar @{$parray} == 1) || ($antec->functor eq 'APPS')) {
		$gen = $parray->[0]->gram_gender;
		$num = $parray->[0]->gram_number;
	}
	else {
		$num = 'pl';
		my %gens = (anim => 0, inan => 0, fem => 0, neut => 0);
		foreach (@{$parray}) {
            if (defined $_->gram_gender) {
			    $gens{$_->gram_gender}++;
            }
		}
		if ($gens{'anim'}) {
			$gen = 'anim';
		}
		elsif (($gens{'fem'} == scalar @{$parray}) || 
            ($gens{'fem'} && $gens{'neut'})) {
			$gen = 'fem';
		}
		elsif ($gens{'neut'} == scalar @{$parray}) {
			$gen = 'neut';
		}
		else  {
			$gen = 'inan';
		}
	}
	return ($gen, $num);
}

# returns the gender and number of the candidate, which is relative, according to his antecedent's gender and number
sub _get_relat_gennum {
	my ($node) = @_;
	my @epars = $node->get_eparents({or_topological => 1});
	my $par = $epars[0];
	while ($par && !($par->is_root) && !(defined $par->gram_sempos && ($par->gram_sempos eq "v") 
        && defined $par->gram_tense && ($par->gram_tense =~ /^(sim|post|ant)$/))) {
		
        @epars = $par->get_eparents({or_topological => 1});
		$par = $epars[0];
	}

	my @antecs = ();
    if (!$par->is_root) {
# TODO this should be get_echildren, shouldn't it be?
        @antecs = $par->get_eparents({or_topological => 1});
    }
	return _get_coord_gennum(\@antecs, $node);
}

### returns the gender and number of the candidate, which is reflexive, according to his antecedent's gender and number
sub _get_refl_gennum {
	my ($node) = @_;
	while ((!$node->gram_gender || ($node->gram_gender eq 'inher')) && (my ($antec) = $node->get_coref_gram_nodes)) {
        $node = $antec;
	}
    my $gen = $node->gram_gender;
	return ($gen, $node->gram_number);
}

### returns the gender and number of the candidate, if cand = relative => get_relat_gennum(cand), if cand = refl => get_refl_gennum(cand)
sub _get_cand_gennum {
	my ($node) = @_;
	if (my ($ante) = $node->get_coref_gram_nodes()) {
		if (defined $node->gram_indeftype && 
                ($node->gram_indeftype eq 'relat')) {


#			my $alex = $node->attr('a/lex.rf');
			my $anode = $node->get_lex_anode;
			my $alemma = $anode->lemma;
	
			if ($alemma !~ /^což/) {
				return _get_relat_gennum($node);
			}
		}
		elsif (($node->t_lemma eq '#PersPron') 
            && ($node->gram_person eq 'inher')) {
			return _get_refl_gennum($ante);
		}
	}
    my $gen = $node->gram_gender;
	return ($gen, $node->gram_number);
}

# returns the symbol in the $position of analytical node's tag of $node
sub _get_atag {
	my ($node, $position) = @_;
	my $anode = $node->get_lex_anode;
    if ($anode) {
		return substr($anode->tag, $position, 1);
	}
    return;
}

sub _valency_for_prodrops {
    my ($self, $node, $coref_features, $type) = @_;

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
        $coref_features->{$type.'_nom_sibling'} = $b_true;
        $coref_features->{$type.'_nom_sibling_epar_lemma'} = $b_true . '_' . $par->t_lemma;
    }
    $coref_features->{$type.'_too_many_acc'} = $b_true if (_too_many_acc_among_siblings($node, $frame, @siblings));
    if ($coref_features->{$type.'_too_many_acc'} && $coref_features->{$type.'_nom_sibling'}) {
        $coref_features->{$type.'_too_many_acc_nom_sibling'} = $b_true;
        $coref_features->{$type.'_too_many_acc_nom_sibling_epar_lemma'} = $b_true .'_'. $par->t_lemma;
    }
    if (_nominative_refused_by_valency($node, $frame, @siblings)) {
        $coref_features->{$type.'_nom_refused'} = $b_true;
        $coref_features->{$type.'_nom_refused_epar_lemma'} = $b_true .'_'. $par->t_lemma;
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

override 'init_doc_features_from_trees' => sub {
    my ($self, $trees) = @_;
    super();
    
    $self->count_collocations( $trees );
    $self->count_np_freq( $trees );
};

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

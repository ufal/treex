package Treex::Block::Print::ItTranslData;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

use Treex::Tool::TranslationModel::Features::It;

extends 'Treex::Core::Block';

has 'pron_type' => ( isa => enum([qw/it refl/]), is => 'ro', required => 1, default => 'it' );
has 'data_type' => ( isa => enum([qw/pcedt czeng/]), is => 'ro', required => 1, default => 'pcedt' );

has '_feat_extractor' => (
    is => 'ro',
    isa => 'Treex::Tool::TranslationModel::Features::It',
    lazy => 1,
    builder => '_build_feat_extractor',
);

sub BUILD {
    my ($self) = @_;
    $self->_feat_extractor;
}

sub _build_feat_extractor {
    my ($self) = @_;
    my $params = {};
    if ($self->pron_type eq "it") {
        $params = {
            adj_compl_path => '/home/mnovak/projects/mt_coref/model/adj.compl',
            verb_func_path => '/home/mnovak/projects/mt_coref/model/czeng0.verb.func',
        };
    }
    return Treex::Tool::TranslationModel::Features::It->new($params);
}

sub _get_aligned_nodes_pcedt {
    my ($self, $tnode) = @_;

    my $t_csrefs = $self->_csrefs_from_ensrc($tnode);

    #if ($tnode->get_address eq "data/train.pcedt/wsj_0258.streex##8.t_tree-en_src-s8-n832") {
    #    use Data::Dumper;
    #    print STDERR "STRANGE_CASE:\n";
    #    print STDERR Dumper([$t_csrefs, $t_has_enref]);
    #}
    
    # "en-src" -> "en-ref" -> "cs-ref" existed
    #return ($t_csrefs, undef) if (@$t_csrefs);
    # should never occur
    #return ([], undef) if ($t_has_enref);
        
    my $anode = $tnode->get_lex_anode;
    my $a_csrefs = $self->_csrefs_from_ensrc($anode);
    
    #log_warn "NO_A_MONOALIGN: this should not happen (" . $tnode->get_address . ")\n" if (defined $a_has_enref && ($a_has_enref == 0));

    return ($t_csrefs, $a_csrefs);

}

sub _csrefs_from_ensrc {
    my ($self, $ensrc) = @_;
    
    # moving to "en-ref" nodes via monolingual alignment
    my @enrefs = grep {$_->is_aligned_to($ensrc, 'monolingual')} $ensrc->get_referencing_nodes('alignment');
    return [] if ( @enrefs == 0 );
    
    # getting all nodes aligned with the first "en-ref"
    my ($aligns, $type) = $enrefs[0]->get_aligned_nodes;
    return [] if (!$aligns || !$type);
    
    # collecting all aligned nodes except for those monolingually aligned - supposed to be "cs-ref"
    my @csrefs = map {$aligns->[$_]} grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    return \@csrefs;
}

sub _get_aligned_nodes_czeng {
    my ($self, $tnode) = @_;

    my @t_cssrc = grep {!$_->is_aligned_to($tnode, 'monolingual')} $tnode->get_referencing_nodes('alignment');
    my $anode = $tnode->get_lex_anode;
    my @a_cssrc = grep {!$_->is_aligned_to($anode, 'monolingual')} $anode->get_referencing_nodes('alignment');
    return (\@t_cssrc, \@a_cssrc);
}

sub aligned_nodes {
    my ($self, $tnode) = @_;

    my ($aligned_t, $aligned_a);
    if ($self->data_type eq 'pcedt') {
        ($aligned_t, $aligned_a) = $self->_get_aligned_nodes_pcedt($tnode);
    } else {
        ($aligned_t, $aligned_a) = $self->_get_aligned_nodes_czeng($tnode);
    }
    return ($aligned_t, $aligned_a);
}

sub aligned_lemmas {
    my ($aligned_t, $aligned_a) = @_;
    return ([map {$_->t_lemma} @$aligned_t], [map {$_->lemma} @$aligned_a]);
}

# for a given "it" in src, returns the t-lemma of a node from cs_ref,
# which has the same functor and both are governed by mutually aligned nodes (verbs)
# can be used only on analysed PCEDT
sub _get_gold_counterpart_tlemma {
    my ($self, $ensrc_it) = @_;
    
    my $a_ensrc_it = $ensrc_it->get_lex_anode;
    my ($a_enref_it) = grep {$_->is_aligned_to($a_ensrc_it, 'monolingual')} $a_ensrc_it->get_referencing_nodes('alignment');
    return "__NO_A_ENREF__" if !$a_enref_it;
    my ($enref_it) = $a_enref_it->get_referencing_nodes('a/lex.rf');
    return "__NO_T_ENREF__" if !$enref_it;

    my ($enref_par) = grep {$_->formeme && ($_->formeme =~ /^v/)} $enref_it->get_eparents;
    return "__NO_V_ENREF_PAR__" if !$enref_par;
    my ($aligns, $type) = $enref_par->get_aligned_nodes;
    return "__NO_CSREF_PAR__" if (!$aligns || !$type);
        
    my ($csref_par) = grep {$_->formeme =~ /^v/} map {$aligns->[$_]} grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    return $self->_gold_counterpart_tlemma_via_alayer($a_enref_it, $enref_it) if !$csref_par;

    my ($csref_it) = grep {$_->functor eq $enref_it->functor} $csref_par->get_echildren;
    return "__NO_CSREF__" if !$csref_it;
    return $csref_it->t_lemma;
}

sub _gold_counterpart_tlemma_via_alayer {
    my ($self, $a_enref_it, $enref_it) = @_;

    my ($a_enref_par) = grep {defined $_->tag && ($_->tag =~ /^V/)} $a_enref_it->get_eparents;
    return "__A:NO_A_V_ENREF_PAR__" if !$a_enref_par;

    my ($aligns, $type) = $a_enref_par->get_aligned_nodes;
    return "__A:NO_A_CSREF_PAR1__" if (!$aligns || !$type);
    my ($a_csref_par) = map {$aligns->[$_]} grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    return "__A:NO_A_CSREF_PAR2__" if !$a_csref_par;
    my ($csref_par) = $a_csref_par->get_referencing_nodes('a/lex.rf');
    return "__A:NO_CSREF_PAR__" if !$csref_par;

    my ($csref_it) = grep {$_->functor eq $enref_it->functor} $csref_par->get_echildren({or_topological => 1});
    return "__A:NO_CSREF__" if !$csref_it;
    return "A:".$csref_it->t_lemma;
}

sub _extract_it_class {
    my ($tlemmas, $alemmas) = @_;

    if (@$tlemmas) {
        return "<" . (join ":", @$tlemmas) . ">";
    } else {
        return "<alemmas=<" . (join ":", @$alemmas) . ">>";
    }
}

sub process_it {
    my ($self, $tnode) = @_;
    return if ($tnode->t_lemma ne "#PersPron");

    # TRANSLATION OF "IT" - can be possibly left out => translation of "#PersPron"
    my $anode = $tnode->get_lex_anode;
    return if (!$anode || ($anode->lemma ne "it"));
    
    my ($tnodes, $anodes) = $self->aligned_nodes($tnode);
    my ($tlemmas, $alemmas) = aligned_lemmas($tnodes, $anodes);
    my $class = _extract_it_class($tlemmas, $alemmas);
    
    my @features = $self->_feat_extractor->get_features($self->pron_type, $tnode);
    push @features, "gcp=" . $self->_get_gold_counterpart_tlemma($tnode);
    return @features;
}

sub _extract_refl_class {
    my ($alemmas) = @_;
    
    my @contains_se = grep {$_ =~ /^se_/} @$alemmas;
    my @contains_sam = grep {$_ =~ /^sám_/} @$alemmas;
    my @contains_samotny = grep {$_ =~ /^samotný$/} @$alemmas;

    return "<SAM_SE>" if (@contains_se && @contains_sam);
    return "<SAM>" if (@contains_sam);
    return "<SE>" if (@contains_se);
    return "<SAMOTNY>" if (@contains_samotny);
    return undef;
    #return "<alemmas=<" . (join ":", @$alemmas) . ">>";
}

sub process_refl {
    my ($self, $tnode) = @_;

    my $anode = $tnode->get_lex_anode;
    return if !$anode;
    my $alemma = $anode->lemma;
    return if $alemma !~ /(myself)|(yourself)|(himself)|(herself)|(itself)|(ourselves)|(themselves)/;
    
    my ($tnodes, $anodes) = $self->aligned_nodes($tnode);
    my ($tlemmas, $alemmas) = aligned_lemmas($tnodes, $anodes);
    my $class = _extract_refl_class($alemmas);

    my @features = $self->_feat_extractor->get_features($self->pron_type, $tnode, $tnodes);

    return ($class, @features);
}

sub process_tnode {
    my ($self, $tnode) = @_;
    
    my @feats;
    my $class;
    if ($self->pron_type eq 'it') {
        @feats = $self->process_it($tnode);
    }
    elsif ($self->pron_type eq 'refl') {
        ($class, @feats) = $self->process_refl($tnode);
    }
    return if (!$class || !@feats);
    
    print $class . "\t" . (join " ", @feats) . "\n";
}

1;

# TODO POD

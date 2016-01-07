package Treex::Tool::Coreference::Features::Aligned;

use Moose;
use Treex::Core::Common;
#use Cache::MemoryCache;

extends 'Treex::Tool::Coreference::CorefFeatures';

has 'feat_extractors' => (is => 'ro', isa => 'ArrayRef[Treex::Tool::Coreference::CorefFeatures]', required => 1);

has 'align_lang' => (is => 'ro', isa => 'Treex::Type::LangCode', required => 1);
#has 'align_selector' => (is => 'ro', isa => 'Treex::Type::Selector', required => 1);
has 'align_types' => (is => 'ro', isa => 'ArrayRef[Str]');

has '_align_filter' => (is => 'ro', isa => 'HashRef', builder => '_build_align_filter', lazy => 1);

#has '_unary_feats_cache' => (is => 'ro', isa => 'Cache::MemoryCache', builder => '_build_unary_feats_cache');

sub BUILD {
    my ($self) = @_;
    $self->_align_filter;
}

sub _build_align_filter {
    my ($self) = @_;
    my $align_filter = {language => $self->align_lang};
    if (defined $self->align_types) {
        $align_filter->{rel_types} = $self->align_types;
    }
    return $align_filter;
}

sub _build_unary_feats_cache {
    my ($self) = @_;
    return Cache::MemoryCache->new({default_expires_in => 30});
}

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my ($ali_anaph_nodes, $ali_anaph_types) = $anaph->get_undirected_aligned_nodes($self->_align_filter);
# TODO: features based on the errors returned
    return {} if (!@$ali_anaph_nodes);
    log_debug "[Tool::Coreference::Features::Aligned::_binary_features]\tanaphor ali_types: " . (join " ", @$ali_anaph_types), 1;
    my ($ali_cand_nodes, $ali_cand_types) = $cand->get_undirected_aligned_nodes($self->_align_filter);
# TODO: features based on the errors returned
    return {} if (!@$ali_cand_nodes);
    log_debug "[Tool::Coreference::Features::Aligned::_binary_features]\tcand ali_types: " . (join " ", @$ali_cand_types), 1;

    # check if unary features (with no "align" prefix) are already in the cache
    # if not => filter the alignment feats out of the $set_features
    #my $ali_set_features_anaph = $self->_unary_feats_cache->get($ali_anaph_nodes->[0]->id);
    #my $ali_set_features_cand = $self->_unary_feats_cache->get($ali_cand_nodes->[0]->id);
    my $ali_set_features;
    #if ($ali_set_features_anaph && $ali_set_features_cand) {
    #    $ali_set_features = { %$ali_set_features_anaph, %$ali_set_features_cand };
    #}
    #else {
        $ali_set_features = {};
        foreach my $key (grep {$_ =~ /^align_/} (keys %$set_features)) {
            my $new_key = $key;
            $new_key =~ s/^align_//;
            $ali_set_features->{$new_key} = $set_features->{$key};
        }
    #}
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_binary_features($ali_set_features, $ali_anaph_nodes->[0], $ali_cand_nodes->[0], $candord);
        %feats = (%feats, %$fe_feats);
    }

    return _add_prefix(\%feats);
};

override '_unary_features' => sub {
    my ($self, $node, $type) = @_;

    my ($ali_nodes, $ali_types) = $node->get_undirected_aligned_nodes($self->_align_filter);
# TODO: features based on the errors returned
    return {} if (!@$ali_nodes);
    log_debug "[Tool::Coreference::Features::Aligned::_unary_features]\tanaphor ali_types: " . (join " ", @$ali_types), 1;
    
    #my $feats = $self->_unary_feats_cache->get($ali_nodes->[0]->id);
    #if (!$feats) {
        my $feats = {};
        foreach my $fe (@{$self->feat_extractors}) {
            my $fe_feats = $fe->_unary_features($ali_nodes->[0], $type);
            $feats = { %$feats, %$fe_feats };
        }
    #    $self->_unary_feats_cache->set($ali_nodes->[0]->id, $feats);
    #}

    return _add_prefix($feats);
};

override 'init_doc_features' => sub {
    my ($self, $doc, $lang, $sel) = @_;
    
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->init_doc_features($doc, $self->align_lang, $sel);
    }
};

sub _add_prefix {
    my ($feats) = @_;
    my %renamed_feats = map { 'align_'.$_ => $feats->{$_} } (keys %$feats);
    return \%renamed_feats;
}


1;


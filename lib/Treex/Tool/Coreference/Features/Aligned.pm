package Treex::Tool::Coreference::Features::Aligned;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;

with 'Treex::Tool::Coreference::CorefFeatures';

has 'feat_extractors' => (is => 'ro', isa => 'ArrayRef[Treex::Tool::Coreference::CorefFeatures]', required => 1);

has 'align_lang' => (is => 'ro', isa => 'Treex::Type::LangCode', required => 1);
#has 'align_selector' => (is => 'ro', isa => 'Treex::Type::Selector', required => 1);
has 'align_types' => (is => 'ro', isa => 'ArrayRef[Str]');

has '_align_filter' => (is => 'ro', isa => 'HashRef', builder => '_build_align_filter', lazy => 1);

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

sub _binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my ($ali_anaph_nodes, $ali_anaph_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($anaph, $self->_align_filter);
# TODO: features based on the errors returned
    return {} if (!@$ali_anaph_nodes);
    log_debug "[Tool::Coreference::Features::Aligned::_binary_features]\tanaphor ali_types: " . (join " ", @$ali_anaph_types), 1;
    my ($ali_cand_nodes, $ali_cand_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($cand, $self->_align_filter);
# TODO: features based on the errors returned
    return {} if (!@$ali_cand_nodes);
    log_debug "[Tool::Coreference::Features::Aligned::_binary_features]\tcand ali_types: " . (join " ", @$ali_cand_types), 1;
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_binary_features($set_features, $ali_anaph_nodes->[0], $ali_cand_nodes->[0], $candord);
        %feats = (%feats, %$fe_feats);
    }

    my %renamed_feats = map { 'align_'.$_ => $feats{$_} } (keys %feats);

    return \%renamed_feats;
}

sub _unary_features {
    my ($self, $node, $type) = @_;

    my ($ali_nodes, $ali_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($node, $self->_align_filter);
# TODO: features based on the errors returned
    return {} if (!@$ali_nodes);
    log_debug "[Tool::Coreference::Features::Aligned::_unary_features]\tanaphor ali_types: " . (join " ", @$ali_types), 1;
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_unary_features($ali_nodes->[0], $type);
        %feats = (%feats, %$fe_feats);
    }

    my %renamed_feats = map { 'align_'.$_ => $feats{$_} } (keys %feats);

    return \%renamed_feats;
}

sub init_doc_features {
    my ($self, $doc, $lang, $sel) = @_;
    
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->init_doc_features($doc, $self->align_lang, $sel);
    }
}


1;


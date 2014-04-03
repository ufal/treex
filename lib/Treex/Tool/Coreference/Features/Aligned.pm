package Treex::Tool::Coreference::Features::Aligned;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;

with 'Treex::Tool::Coreference::CorefFeatures';

has 'feat_extractors' => (is => 'ro', isa => 'ArrayRef[Treex::Tool::Coreference::CorefFeatures]', required => 1);

has 'align_sieves' => (is => 'ro', isa => 'ArrayRef', required => 1);
has 'align_filters' => (is => 'ro', isa => 'ArrayRef', required => 1);
has 'align_lang' => (is => 'ro', isa => 'Treex::Type::LangCode', required => 1);
has 'align_selector' => (is => 'ro', isa => 'Treex::Type::Selector', required => 1);

has '_align_zone' => (is => 'ro', isa => 'HashRef[Str]', builder => '_build_align_zone', lazy => 1);

sub BUILD {
    my ($self) = @_;
    $self->_align_zone;
}

sub _build_align_zone {
    my ($self) = @_;
    return {language => $self->align_lang, selector => $self->align_selector};
}

sub _binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my ($aligned_anaph, $a_errors) = Treex::Tool::Align::Utils::aligned_robust($anaph, [$self->_align_zone], $self->align_sieves, $self->align_filters);
# TODO: features based on the errors returned
    return {} if (!defined $aligned_anaph);
    my ($aligned_cand, $c_errors) = Treex::Tool::Align::Utils::aligned_robust($cand, [$self->_align_zone], $self->align_sieves, $self->align_filters);
# TODO: features based on the errors returned
    return {} if (!defined $aligned_cand);
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_binary_features($set_features, $aligned_anaph, $aligned_cand, $candord);
        %feats = (%feats, %$fe_feats);
    }

    my %renamed_feats = map { 'align_'.$_ => $feats{$_} } (keys %feats);

    return \%renamed_feats;
}

sub _unary_features {
    my ($self, $node, $type) = @_;

    my ($aligned_node, $errors) = Treex::Tool::Align::Utils::aligned_robust($node, [$self->_align_zone], $self->align_sieves, $self->align_filters);
# TODO: features based on the errors returned
    return {} if (!defined $aligned_node);
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_unary_features($aligned_node, $type);
        %feats = (%feats, %$fe_feats);
    }

    my %renamed_feats = map { 'align_'.$_ => $feats{$_} } (keys %feats);

    return \%renamed_feats;
}

sub init_doc_features {
    my ($self, $doc, $lang, $sel) = @_;
    
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->init_doc_features($doc, $self->align_lang, $self->align_selector);
    }
}


1;


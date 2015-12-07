package Treex::Block::Align::T::Supervised::Base;

use Moose::Role;

use Treex::Tool::Align::FeaturesRole;
use Treex::Tool::Align::Features;

has '_feat_extractor' => (is => 'ro', isa => 'Treex::Tool::Align::FeaturesRole', builder => '_build_feat_extractor');

sub _build_feat_extractor {
    my ($self) = @_;
    return Treex::Tool::Align::Features->new();
}

sub _get_candidates {
    my ($self, $tnode, $align_lang) = @_;
    my $aligned_ttree = $tnode->get_bundle->get_zone($align_lang, $self->selector)->get_ttree();
    my @candidates = $aligned_ttree->get_descendants({ordered => 1});
    
    # add the src node itself as a candidate -> it means no alignment
    unshift @candidates, $tnode;
    
    return @candidates;
}

1;

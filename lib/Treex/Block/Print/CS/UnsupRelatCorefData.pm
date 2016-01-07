package Treex::Block::My::UnsupCSRelPronData;

use Moose;

use Treex::Tool::Coreference::AnteCandsGetter;
use Treex::Tool::Coreference::CS::RelPronAnaphFilter;

extends 'Treex::Block::Print::CS::TextPronCorefData';

has '+unsupervised' => (
    default => 1,
);

has '+format' => (
    default => 'unsup',
);

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    
    my @feat_names = qw/
        cand_id
        c_cand_ord
        c_cand_gen
        c_anaph_gen
        c_cand_num
        c_anaph_num
    /;

    my $fe = Treex::Tool::Coreference::CS::PronCorefFeatures->new({
        feature_names => \@feat_names,
        format        => 'unsup',
    });
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::AnteCandsGetter->new({
        cand_types => [ 'noun.3_pers' ],        
        prev_sents_num => 0,
        #anaphor_as_candidate => 1,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    my $acf = Treex::Tool::Coreference::CS::RelPronAnaphFilter->new();
    return $acf;
};

1;

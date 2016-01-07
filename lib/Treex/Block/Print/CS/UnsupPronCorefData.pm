package Treex::Block::My::UnsupCSPersPronData;

use Moose;

use Treex::Tool::Coreference::AnteCandsGetter;

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
        c_sent_dist
        c_cand_gen
        c_anaph_gen
        c_cand_num
        c_anaph_num
        c_cand_epar_lemma
        c_anaph_epar_lemma
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
        prev_sents_num => 1,
        #anaphor_as_candidate => 1,
    });
    return $acs;
};

1;

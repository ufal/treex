package Treex::Block::A2T::EN::MarkTextPronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::BaseMarkCoref';

use Treex::Tool::Coreference::PerceptronRanker;
use Treex::Tool::Coreference::EN::PronCorefFeatures;
use Treex::Tool::Coreference::NounAnteCandsGetter;
use Treex::Tool::Coreference::EN::PronAnaphFilter;

has '+model_path' => (
    default => 'data/models/coreference/EN/perceptron/text.perspron.analysed',
);

override '_build_ranker' => sub {
    my ($self) = @_;
    my $ranker = Treex::Tool::Coreference::PerceptronRanker->new( 
        { model_path => $self->model_path } 
    );
    return $ranker;
};

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    my $fe = Treex::Tool::Coreference::EN::PronCorefFeatures->new();
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::NounAnteCandsGetter->new({
        prev_sents_num => 1,
        anaphor_as_candidate => 1,
        cands_within_czeng_blocks => 1,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    my $acf = Treex::Tool::Coreference::EN::PronAnaphFilter->new();
    return $acf;
};

1;

=over

=item Treex::Block::A2T::EN::MarkTextPronCoref


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

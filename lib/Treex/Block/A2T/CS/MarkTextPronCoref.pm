package Treex::Block::A2T::CS::MarkTextPronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::BaseMarkCoref';

#use Treex::Tool::Coreference::PerceptronRanker;
#use Treex::Tool::Coreference::RuleBasedRanker;
#use Treex::Tool::Coreference::ProbDistrRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;
use Treex::Tool::Coreference::CS::PronCorefFeatures;
use Treex::Tool::Coreference::AnteCandsGetter;
use Treex::Tool::Coreference::NodeFilter::PersPron;

has '+model_path' => (
    #default => 'data/models/coreference/CS/vw/perspron.2015-04-29.train.pdt.cs.vw.ranking.model',
    default => 'data/models/coreference/CS/vw/perspron.2015-11-16.train.pdt.cs.vw.ranking.model',
);

override '_build_ranker' => sub {
    my ($self) = @_;
#    my $ranker = Treex::Tool::Coreference::RuleBasedRanker->new();
#    my $ranker = Treex::Tool::Coreference::ProbDistrRanker->new(
#    my $ranker = Treex::Tool::Coreference::PerceptronRanker->new( 
    my $ranker = Treex::Tool::ML::VowpalWabbit::Ranker->new( 
        { model_path => $self->model_path } 
    );
    return $ranker;
};

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    #my $fe = Treex::Tool::Coreference::CS::PronCorefFeatures->new();
    my $fe = Treex::Tool::Coreference::CS::PronCorefFeatures->new({
    #    format => 'unsup'
    });
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::AnteCandsGetter->new({
        cand_types => [ 'noun.3_pers' ],
        prev_sents_num => 1,
        anaphor_as_candidate => 1,
        cands_within_czeng_blocks => 1,
        max_size => 100,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    my $args = {
        #skip_nonref => 1,
        # both expressed and unexpressed
        expressed => 0,
        # excluding reflexive pronouns
        reflexive => -1,
    };
    my $acf = Treex::Tool::Coreference::NodeFilter::PersPron->new({args => $args});
    return $acf;
};

1;

=over

=item Treex::Block::A2T::CS::MarkTextPronCoref


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

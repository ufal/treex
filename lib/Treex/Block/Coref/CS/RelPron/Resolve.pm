package Treex::Block::Coref::CS::RelPron::Resolve;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::CS::RelPron::Base';

#use Treex::Tool::Coreference::PerceptronRanker;
#use Treex::Tool::Coreference::RuleBasedRanker;
#use Treex::Tool::Coreference::ProbDistrRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_path' => (
    #default => 'data/models/coreference/CS/vw/perspron.2015-04-29.train.pdt.cs.vw.ranking.model',
    #default => 'data/models/coreference/CS/vw/relpron.2016-04-24.train.pdt.cs.vw.ranking.model',
    # MODEL FOR RelPron FEATS
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/relpron/tmp/ml/009_run_2016-04-26_17-52-36_1614.bugfix_of_number_and_gender_joins_and_agrees/004.8b2c8f04b5.featset/002.f59b5.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    # MODEL FOR AllMonolingual FEATS
    default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/relpron/tmp/ml/011_run_2016-08-31_17-28-05_7096.PDT.an_all-types_joint_feature_set_+_nodetype_feats_in_separate_ns/002.e5ce78c10f.featset/018.22ec1.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
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

1;

#TODO adjust documentation

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::CS::RelPron::Resolve

=head1 DESCRIPTION

Pronoun coreference resolver for Czech.
Settings:
* English personal pronoun filtering of anaphor
* candidates for the antecedent are nouns from current (prior to anaphor) and previous sentence
* English pronoun coreference feature extractor
* using a model trained by a perceptron ranker

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

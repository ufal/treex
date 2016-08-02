package Treex::Block::Coref::CS::PersPron::Resolve;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::CS::PersPron::Base';

#use Treex::Tool::Coreference::PerceptronRanker;
#use Treex::Tool::Coreference::RuleBasedRanker;
#use Treex::Tool::Coreference::ProbDistrRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_path' => (
    #default => 'data/models/coreference/CS/vw/perspron.2015-04-29.train.pdt.cs.vw.ranking.model',
    #default => 'data/models/coreference/CS/vw/perspron.2015-11-16.train.pdt.cs.vw.ranking.model',
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/run_2016-08-02_22-11-13_12827.data_0008_+_prodrop_valency_and_epar_diathesis_combined/005.a3ea81be31.featset/004.37316.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/run_2016-08-02_22-11-13_12827.data_0008_+_prodrop_valency_and_epar_diathesis_combined/006.a58a87ab5b.featset/004.37316.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    # UDPipe W2A
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/run_2016-07-20_11-29-14_21681.data_0007_-_UDPipe_W2A/001.6482ae07e1.featset/002.f59b5.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    # new limited features
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/run_2016-07-03_19-46-00_17837.using_Coreference_Features_PersPron_-_new_features_-_so_far_limited/004.bc3425f2a5.featset/003.202e7.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
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

Treex::Block::Coref::CS::PersPron::Resolve

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

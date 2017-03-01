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
    # PDT monolingual
    #################
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/021_run_2016-08-25_18-10-03_13500.PDT.new_prodrop_filter/001.e6a6d5dba6.featset/004.37316.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    # joint feature set
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/023_run_2016-08-30_23-38-36_9360.PDT.an_all-types_joint_feature_set/001.3b9f404130.featset/004.37316.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    default => 'data/models/coreference/CS/vw/perspron.2016-08-30.train.pdt.cs.vw.ranking.model',
    # UDPipe W2A
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/010_run_2016-07-20_11-29-14_21681.data_0007_-_UDPipe_W2A/001.6482ae07e1.featset/002.f59b5.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    # new limited features
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/004_run_2016-07-03_19-46-00_17837.using_Coreference_Features_PersPron_-_new_features_-_so_far_limited/004.bc3425f2a5.featset/003.202e7.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    
    # PCEDT monolingual
    #################
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/022_run_2016-08-25_18-40-12_14840.PCEDT.new_prodrop_filter/001.e6a6d5dba6.featset/004.37316.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model',
    # joint feature set
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/025_run_2016-09-21_20-10-12_17102.PCEDT.all-monolingual_featset_+_nodetypes/001.3b9f404130.featset/004.39acd.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model',
    
    # PCEDT cross-lingual
    #################
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/022_run_2016-08-25_18-40-12_14840.PCEDT.new_prodrop_filter/004.68ab891a00.featset/004.37316.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model',
    # joint feature set
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/025_run_2016-09-21_20-10-12_17102.PCEDT.all-monolingual_featset_+_nodetypes/008.896a848f42.featset/002.22ec1.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model',
    
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

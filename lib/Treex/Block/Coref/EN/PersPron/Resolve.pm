package Treex::Block::Coref::EN::PersPron::Resolve;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::EN::PersPron::Base';

#use Treex::Tool::Coreference::PerceptronRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_path' => (
    # $CZENG_COREF/tmp/ml/run_2015-04-04_12-44-16_9036.testing_on_English/001.8f801ad5b1.featset/001.134ca.mlmethod/model/train_00-18.pcedt_bi.en.analysed.ali-sup.vw.ranking.model
    #default => 'data/models/coreference/EN/vowpal_wabbit/2015-04-04.perspron_3rd.mono_all.analysed.model',
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/en/perspron/tmp/ml/run_2016-06-25_23-39-19_23805.training_on_0020._original_features/001.b9be16d2b7.featset/002.f59b5.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model'
    default => '/home/mnovak/projects/czeng_coref/treex_cr_train/en/perspron/tmp/ml/run_2016-06-26_14-50-51_9841.training_on_0020._original_features._feature_correction/001.b9be16d2b7.featset/004.37316.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model'
);

override '_build_ranker' => sub {
    my ($self) = @_;
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

Treex::Block::Coref::EN::PersPron::Resolve

=head1 DESCRIPTION

Pronoun coreference resolver for English.
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

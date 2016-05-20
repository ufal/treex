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
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/run_2016-04-25_11-25-07_17770.cs-perspron_within_a_new_directory_+_a_and_c_namespaces/003.fcc2aaeffe.featset/001.7eb17.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml/run_2016-04-27_10-39-34_18736.fixed_features_for_joins_and_agrees/002.c2b8206b36.featset/004.37316.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
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

package Treex::Block::Coref::EN::RelPron::Resolve;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::EN::RelPron::Base';

#use Treex::Tool::Coreference::PerceptronRanker;
#use Treex::Tool::Coreference::RuleBasedRanker;
#use Treex::Tool::Coreference::ProbDistrRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_path' => (
    #default => 'data/models/coreference/CS/vw/perspron.2015-04-29.train.pdt.cs.vw.ranking.model',
    #default => 'data/models/coreference/CS/vw/relpron.2016-04-24.train.pdt.cs.vw.ranking.model',
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/relpron/tmp/ml/run_2016-04-26_15-22-11_14088.cand_ancestor_features/003.610457c11c.featset/001.7eb17.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    #default => '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/relpron/tmp/ml/run_2016-04-26_17-35-08_12399.adding_features_based_on_nodes_in_between/004.8b2c8f04b5.featset/002.f59b5.mlmethod/model/train.pdt.table.gz.vw.ranking.model',
    default => '/home/mnovak/projects/czeng_coref/treex_cr_train/en/relpron/tmp/ml/run_2016-06-16_14-02-13_10084.data_regenerated._cors_for_instead_of_missing_relprons_added/004.8b2c8f04b5.featset/001.7eb17.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model',
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

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Coref::EN::RelPron::Resolve

=head1 DESCRIPTION

Pronoun coreference resolver for English.
Settings:
* English relative, interrogative or fused pronoun as anaphor candidates
* antecedent candidates are nouns from the current sentence (also the following context)
* English relative pronoun coreference feature extractor
* using a model trained by a VW ranker

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

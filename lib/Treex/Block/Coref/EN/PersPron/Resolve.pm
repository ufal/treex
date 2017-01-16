package Treex::Block::Coref::EN::PersPron::Resolve;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::EN::PersPron::Base';

use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_type' => ( isa => enum([qw/pcedt_bi pcedt_bi.with_en/]), default => 'pcedt_bi' );

override '_build_model_for_type' => sub {
    my $dir = '/home/mnovak/projects/czeng_coref/treex_cr_train/en/perspron/tmp/ml';
    return {
        'pcedt_bi' => "$dir/run_2016-07-01_20-06-47_19333.training_with_aligned_feats/001.b9be16d2b7.featset/004.37316.mlmethod/model/train.pcedt_bi.with_cs.table.gz.vw.ranking.model",
        #'pcedt_bi.with_en' => "$dir/027_run_2017-01-14_02-37-37_21334.PCEDT.new_models_with_EN.CS__AllMonolingual_feats/004.7f391f3429.featset/002.22ec1.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model",
    };
};
override '_build_ranker' => sub {
    my ($self) = @_;
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

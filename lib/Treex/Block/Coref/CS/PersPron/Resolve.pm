package Treex::Block::Coref::CS::PersPron::Resolve;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::CS::PersPron::Base';

use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_type' => ( isa => enum([qw/pdt pcedt_bi pcedt_bi.with_en pcedt_bi.with_en.treex_cr pcedt_bi.with_en.base_cr/]), default => 'pdt' );

override '_build_model_for_type' => sub {
    my $dir = '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/perspron/tmp/ml';
    return {
        #'pdt' => "$dir/030_run_2017-01-15_01-09-01_29026.PDT.feats-AllMonolingual.round1/001.17cb9c0d6f.featset/004.39acd.mlmethod/model/train.pdt.table.gz.vw.ranking.model",
        'pdt' => "$dir/034_run_2017-01-17_21-35-41_17073.PDT.monolingual.feats-AllMonolingual/001.17cb9c0d6f.featset/024.9c797.mlmethod/model/train.pdt.table.gz.vw.ranking.model",
        #'pcedt_bi' => "$dir/027_run_2017-01-14_02-37-37_21334.PCEDT.new_models_with_EN.CS__AllMonolingual_feats/001.17cb9c0d6f.featset/002.22ec1.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model",
        'pcedt_bi' => "$dir/033_run_2017-01-17_21-35-31_16903.PCEDT.monolingual.feats-AllMonolingual/001.17cb9c0d6f.featset/024.9c797.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model",
        
        # PCEDT.crosslingual aligned_all
        'pcedt_bi.with_en' => "$dir/035_run_2017-01-18_01-00-27_17627.PCEDT.crosslingual.feats-AllMonolingual/002.88233bf9a2.featset/022.88cd4.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model",
        # PCEDT.crosslingual aligned_all+coref+mono_all
        'pcedt_bi.with_en.treex_cr' => "$dir/035_run_2017-01-18_01-00-27_17627.PCEDT.crosslingual.feats-AllMonolingual/004.7f391f3429.featset/010.22ec1.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model",
        
        # PCEDT.crosslingual-baseline aligned_all+coref+mono_all
        'pcedt_bi.with_en.base_cr' => "$dir/036_run_2017-01-18_15-43-50_23590.PCEDT.crosslingual-baseline.feats-AllMonolingual/004.7f391f3429.featset/010.22ec1.mlmethod/model/train.pcedt_bi.with_en.baseline.table.gz.vw.ranking.model",
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

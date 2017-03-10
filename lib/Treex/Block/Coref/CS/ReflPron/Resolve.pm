package Treex::Block::Coref::CS::ReflPron::Resolve;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::CS::ReflPron::Base';

use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_type' => ( isa => enum([qw/pdt pcedt_bi pcedt_bi.with_en pcedt_bi.with_en.treex_cr pcedt_bi.with_en.base_cr/]), default => 'pdt' );
override '_build_model_for_type' => sub {
    my $dir = '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/reflpron/tmp/ml';
    return {
        #'pdt' => "$dir/004_run_2017-01-15_01-21-00_18893.PDT.feats-AllMonolingual.round1/001.17cb9c0d6f.featset/003.d62b7.mlmethod/model/train.pdt.table.gz.vw.ranking.model",
        'pdt' => "$dir/008_run_2017-01-17_21-35-21_16745.PDT.monolingual.feats-AllMonolingual/001.17cb9c0d6f.featset/018.68fb6.mlmethod/model/train.pdt.table.gz.vw.ranking.model",
        #'pcedt_bi' => "$dir/003_run_2017-01-15_01-20-41_18442.PCEDT.feats-AllMonolingual.round1/001.17cb9c0d6f.featset/001.0017e.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model",
        'pcedt_bi' => "$dir/011_run_2017-03-10_10-33-29_19175.PCEDT.mono.instance_num_fixed/001.17cb9c0d6f.featset/017.d31f8.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model",
        
        # PCEDT.crosslingual aligned_all
        'pcedt_bi.with_en' => "$dir/012_run_2017-03-10_10-33-39_19348.PCEDT.cross.instance_num_fixed/002.88233bf9a2.featset/012.39acd.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model",
        # PCEDT.crosslingual aligned_all+coref+mono_all
        'pcedt_bi.with_en.treex_cr' => "$dir/012_run_2017-03-10_10-33-39_19348.PCEDT.cross.instance_num_fixed/004.7f391f3429.featset/024.9c797.mlmethod/model/train.pcedt_bi.with_en.table.gz.vw.ranking.model",
        
        # PCEDT.crosslingual-baseline aligned_all+coref+mono_all
        'pcedt_bi.with_en.base_cr' => "$dir/013_run_2017-03-10_10-33-49_19543.PCEDT.cross-base.instance_num_fixed/004.7f391f3429.featset/012.39acd.mlmethod/model/train.pcedt_bi.with_en.baseline.table.gz.vw.ranking.model",
    };
};
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

Treex::Block::Coref::CS::ReflPron::Resolve

=head1 DESCRIPTION


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

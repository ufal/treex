package Treex::Block::Coref::CS::Cor::Resolve;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::CS::Cor::Base';

#use Treex::Tool::Coreference::PerceptronRanker;
#use Treex::Tool::Coreference::RuleBasedRanker;
#use Treex::Tool::Coreference::ProbDistrRanker;
use Treex::Tool::ML::VowpalWabbit::Ranker;

# TODO: so far, no #Cor annotation in amutomatic Czech data => no CR used for Czech

has '+model_type' => ( isa => enum([qw/pcedt_bi pcedt_bi.with_en pcedt_bi.with_en.treex_cr pcedt_bi.with_en.base_cr/]), default => 'pcedt_bi' );

override '_build_model_for_type' => sub {
    my $dir = '/home/mnovak/projects/czeng_coref/treex_cr_train/cs/cor/tmp/ml';
# NOTHING TRAINED YET
#    return {
#        #'pcedt_bi' => "$dir/003_run_2017-01-16_10-35-53_22530.PCEDT.feats-AllMonolingual.round1/001.9fd0f3842c.featset/004.39acd.mlmethod/model/train.pcedt_bi.with_cs.table.gz.vw.ranking.model",
#        'pcedt_bi' => "$dir/005_run_2017-01-17_22-34-07_28083.PCEDT.monolingual.feats-AllMonolingual/001.9fd0f3842c.featset/024.9c797.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model",
#        
#        # PCEDT.crosslingual aligned_all
#        'pcedt_bi.with_en' => "$dir/007_run_2017-01-19_00-19-24_9816.PCEDT.crosslingual.feats-AllMonolingual/002.28b9b793e5.featset/024.9c797.mlmethod/model/train.pcedt_bi.with_cs.table.gz.vw.ranking.model",
#        # PCEDT.crosslingual aligned_all+coref+mono_all
#        'pcedt_bi.with_en.treex_cr' => "$dir/007_run_2017-01-19_00-19-24_9816.PCEDT.crosslingual.feats-AllMonolingual/004.191e9db554.featset/024.9c797.mlmethod/model/train.pcedt_bi.with_cs.table.gz.vw.ranking.model",
#        
#        # PCEDT.crosslingual-baseline aligned_all+coref+mono_all
#        'pcedt_bi.with_en.base_cr' => "$dir/006_run_2017-01-18_15-41-37_22245.PCEDT.crosslingual-baseline.feats-AllMonolingual/004.191e9db554.featset/024.9c797.mlmethod/model/train.pcedt_bi.with_cs.baseline.table.gz.vw.ranking.model",
#    };
    return {};
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

Treex::Block::Coref::CS::Cor::Resolve

=head1 DESCRIPTION

Cor coreference resolver for Czech.
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

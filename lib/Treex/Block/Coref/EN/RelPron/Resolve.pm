package Treex::Block::Coref::EN::RelPron::Resolve;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::EN::RelPron::Base';

use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_type' => ( isa => enum([qw/pcedt_bi pcedt_bi.with_en/]), default => 'pcedt_bi' );

override '_build_model_for_type' => sub {
    my $dir = '/home/mnovak/projects/czeng_coref/treex_cr_train/en/relpron/tmp/ml';
    return {
        'pcedt_bi' => "$dir/run_2016-06-16_14-02-13_10084.data_regenerated._cors_for_instead_of_missing_relprons_added/004.8b2c8f04b5.featset/001.7eb17.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model",
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

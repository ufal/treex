package Treex::Block::Coref::EN::ReflPron::Resolve;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::EN::ReflPron::Base';

use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_type' => ( isa => enum([qw/pcedt_bi pcedt_bi.with_en/]), default => 'pcedt_bi' );

override '_build_model_for_type' => sub {
    my $dir = '/home/mnovak/projects/czeng_coref/treex_cr_train/en/reflpron/tmp/ml';
    return {
        #'pcedt_bi' => "$dir/002_run_2017-01-16_10-50-54_14671.PCEDT.feats-AllMonolingual.round1/001.9fd0f3842c.featset/002.22ec1.mlmethod/model/train.pcedt_bi.with_cs.table.gz.vw.ranking.model",
        'pcedt_bi' => "$dir/004_run_2017-01-17_22-34-17_28244.PCEDT.monolingual.feats-AllMonolingual/001.9fd0f3842c.featset/020.b0167.mlmethod/model/train.pcedt_bi.table.gz.vw.ranking.model",
        #'pcedt_bi.with_en' => "$dir/002_run_2017-01-16_10-50-54_14671.PCEDT.feats-AllMonolingual.round1/003.cc47b795e9.featset/002.22ec1.mlmethod/model/train.pcedt_bi.with_cs.table.gz.vw.ranking.model",
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

Treex::Block::Coref::EN::ReflPron::Resolve

=head1 DESCRIPTION


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

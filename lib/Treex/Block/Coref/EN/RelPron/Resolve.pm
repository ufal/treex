package Treex::Block::Coref::EN::RelPron::Resolve;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
extends 'Treex::Block::Coref::Resolve';
with 'Treex::Block::Coref::EN::RelPron::Base';

use Treex::Tool::ML::VowpalWabbit::Ranker;

has '+model_type' => ( isa => enum([qw/pcedt_bi pcedt_bi.with_en pcedt_bi.with_en.treex_cr pcedt_bi.with_en.base_cr/]), default => 'pcedt_bi' );

override '_build_model_for_type' => sub {
    my $dir = 'data/models/coreference/EN/vw';
    return {
        'pcedt_bi' => "$dir/relpron.2017-01-18.train.pcedt_bi.en.vw.ranking.model",
        
        # PCEDT.crosslingual aligned_all
        'pcedt_bi.with_en' => "",
        # PCEDT.crosslingual aligned_all+coref+mono_all
        'pcedt_bi.with_en.treex_cr' => "",
        
        # PCEDT.crosslingual-baseline aligned_all+coref+mono_all
        'pcedt_bi.with_en.base_cr' => "",
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

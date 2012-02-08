package Treex::Block::A2T::EN::MarkTextPronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::BaseMarkCoref';

use Treex::Tool::Coreference::PerceptronRanker;
use Treex::Tool::Coreference::EN::PronCorefFeatures;
use Treex::Tool::Coreference::NounAnteCandsGetter;
use Treex::Tool::Coreference::EN::PronAnaphFilter;

has '+model_path' => (
    default => 'data/models/coreference/EN/perceptron/text.perspron.analysed',
);

override '_build_ranker' => sub {
    my ($self) = @_;
    my $ranker = Treex::Tool::Coreference::PerceptronRanker->new( 
        { model_path => $self->model_path } 
    );
    return $ranker;
};

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    my $fe = Treex::Tool::Coreference::EN::PronCorefFeatures->new();
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::NounAnteCandsGetter->new({
        prev_sents_num => 1,
        anaphor_as_candidate => $self->anaphor_as_candidate,
#        cands_within_czeng_blocks => 1,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    my $acf = Treex::Tool::Coreference::EN::PronAnaphFilter->new();
    return $acf;
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::MarkTextPronCoref

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

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

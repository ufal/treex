package Treex::Block::T2T::EN2CS::TrLPersPronRefl;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use Treex::Tool::ML::Factory;
use Treex::Tool::Compress::Index;
use Treex::Tool::TranslationModel::Features::It;

extends 'Treex::Core::Block';

has 'model_type' => ( is => 'ro', isa => 'Str', default => 'maxent');
has 'model_path' => ( is => 'ro', isa => 'Str', default => 'data/models/translation/en2cs/specialized/perspron_refl.czeng_0.maxent.model' );
#model_path=/home/mnovak/projects/mt_coref/runs/tte_feats_2013-07-28_22-35-53/0ea9043305/model/czeng_0.refl.maxent.adc83.model
#model_path=/home/mnovak/projects/mt_coref/runs/tte_feats_2013-08-03_19-13-02/56634fca6c/model/czeng_0.refl.sklearn.svm.33068.model
has 'index_path' => ( is => 'ro', isa => 'Str', default => 'data/models/translation/en2cs/specialized/perspron_refl.czeng_0.idx' );
#index_path=/home/mnovak/projects/mt_coref/data/train.czeng_0.refl.idx

has '_model' => (
    is => 'ro',
    isa => 'Treex::Tool::ML::Classifier',
    builder => '_build_model',
    lazy => 1,
);

has '_index' => (
    is => 'ro',
    isa => 'Treex::Tool::Compress::Index',
    builder => '_build_index',
    lazy => 1,
);

has '_feat_extractor' => (
    is => 'ro',
    isa => 'Treex::Tool::TranslationModel::Features::It',
    builder => '_build_feat_extractor',
);

sub BUILD {
    my ($self) = @_;
    $self->_model;
    $self->_index;
}

sub _build_model {
    my ($self) = @_;
    my $factory = Treex::Tool::ML::Factory->new();
    my $model = $factory->create_classifier_model($self->model_type);
    $model->load($self->model_path);
    return $model;
}

sub _build_index {
    my ($self) = @_;
    my $index = Treex::Tool::Compress::Index->new();
    $index->load($self->index_path);
    $index->build_inverted_index();
    return $index;
}

sub _build_feat_extractor {
    my ($self) = @_;
    return Treex::Tool::TranslationModel::Features::It->new();
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    if ( my $en_tnode = $cs_tnode->src_tnode ) {
        return if ($en_tnode->t_lemma ne "#PersPron");
        return if !$en_tnode->get_attr('is_reflexive');

        # TODO: share the same library with the printer
        my @features = $self->_feat_extractor->get_features("refl", $en_tnode, [$cs_tnode]);
#        print STDERR "PREDICT START\n";
        my $class_idx = $self->_model->predict(\@features);
#        print STDERR "PREDICT END\n";
        my $class = $self->_index->get_str_for_idx($class_idx);

        foreach my $c (1 .. 4) {
            my $params = $self->_model->log_feat_weights(\@features, $c);
            my $c_name = $self->_index->get_str_for_idx($c);
            $cs_tnode->wild->{$c_name} = $params;
        }

        #log_info "ADDRESS: " . $en_tnode->get_address;
        #log_info "SENT: " . $en_tnode->get_zone->sentence;
        #log_info "CLASS: $class, CLASS_IDX: $class_idx";

        # TODO: decisions
        if ($class eq "<SE>") {
            $cs_tnode->set_t_lemma("#PersPron");
            $cs_tnode->set_t_lemma_origin('ReflTransl');

        }
        elsif ($class eq "<SAM>") {
            $cs_tnode->set_t_lemma("sám");
            $cs_tnode->set_gram_sempos("adj.pron.def.demon");
            $cs_tnode->set_functor("COMPL");
            $cs_tnode->set_formeme("adj:compl");
            $cs_tnode->set_t_lemma_origin('ReflTransl');
        }
        elsif ($class eq "<SAM_SE>") {
            $cs_tnode->set_t_lemma("#PersPron");
            $cs_tnode->set_t_lemma_origin('ReflTransl');
            my $sam_tnode = $cs_tnode->get_parent->create_child();
            $sam_tnode->shift_before_node($cs_tnode);
            $sam_tnode->set_t_lemma("sám");
            $sam_tnode->set_gram_sempos("adj.pron.def.demon");
            $sam_tnode->set_functor("COMPL");
            $sam_tnode->set_formeme("adj:compl");
            $sam_tnode->set_t_lemma_origin('ReflTransl');
        }
        elsif ($class eq "<SAMOTNY>") {
            $cs_tnode->set_t_lemma("samotný");
            $cs_tnode->set_gram_sempos("adj.denot");
            $cs_tnode->set_functor("RSTR");
            $cs_tnode->set_formeme("adj:attr");
            $cs_tnode->set_t_lemma_origin('ReflTransl');
        }

        my $par = $cs_tnode->get_parent();
        if ($par->formeme =~ /^n/) {
            $cs_tnode->shift_before_subtree($par);
        }
    }
#        print STDERR "PROCESS END\n";
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2CS::TrLPersPronRefl

=head1 DESCRIPTION

This block handles translation of English reflexive pronouns into Czech.
It uses a specified classifier desribed in (Novák, Žabokrtský, Nedoluzhko, 2013)
TODO: enter the bib here
TODO: model and index should be encapsulated within a single file

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

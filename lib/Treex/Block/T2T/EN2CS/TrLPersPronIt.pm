package Treex::Block::T2T::EN2CS::TrLPersPronIt;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use Treex::Tool::ML::Factory;
use Treex::Tool::Compress::Index;
use Treex::Tool::TranslationModel::Features::It;

extends 'Treex::Core::Block';

has 'model_type' => ( is => 'ro', isa => 'Str', default => 'maxent');
has 'model_path' => ( is => 'ro', isa => 'Str', default => 'data/models/translation/en2cs/specialized/perspron_it.pcedt.maxent.model' );
#model_path=/home/mnovak/projects/mt_coref/runs/tte_feats_2013-07-24_10-54-49/e28e8f019a/model/pcedt.it.maxent.adc83.model
#model_path=/home/mnovak/projects/mt_coref/runs/tte_feats_2013-07-24_10-54-49/e28e8f019a/model/pcedt.it.vw.f7d62.model
has 'index_path' => ( is => 'ro', isa => 'Str', default => 'data/models/translation/en2cs/specialized/perspron_it.pcedt.idx' );
#index_path=/home/mnovak/projects/mt_coref/data/train.pcedt.it.idx

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

# TODO: move loading of models to process_start (so creating an instance of this class does not take too long)
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
    return Treex::Tool::TranslationModel::Features::It->new({
        #adj_compl_path => '/home/mnovak/projects/mt_coref/model/adj.compl',
        #verb_func_path => '/home/mnovak/projects/mt_coref/model/czeng0.verb.func',
        adj_compl_path => 'data/models/translation/en2cs/specialized/perspron_it.czeng0.adj.compl',
        verb_func_path => 'data/models/translation/en2cs/specialized/perspron_it.czeng0.verb.func',
    });
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

	# This is needed for newstest2014. TODO: why?
    return if ref $cs_tnode eq 'Treex::Core::Node::Deleted';

    if ( my $en_tnode = $cs_tnode->src_tnode ) {
        return if ($en_tnode->t_lemma ne "#PersPron");

        # TRANSLATION OF "IT" - can be possibly left out => translation of "#PersPron"
        my $en_anode = $en_tnode->get_lex_anode;
        return if (!$en_anode || ($en_anode->lemma ne "it"));

#        print STDERR $en_tnode->id . "\n";
    
        # TODO: share the same library with the printer
        my @features = $self->_feat_extractor->get_features("it", $en_tnode);
#        print STDERR "PREDICT START\n";
        my $class_idx = $self->_model->predict(\@features);
#        print STDERR "PREDICT END\n";
        my $class = $self->_index->get_str_for_idx($class_idx);

        #log_info "ADDRESS: " . $en_tnode->get_address;
        #log_info "SENT: " . $en_tnode->get_zone->sentence;
        #log_info "CLASS: $class, CLASS_IDX: $class_idx";

        # TODO: decisions
        if ($class eq "p") {
            $cs_tnode->set_t_lemma("#PersPron");
            $cs_tnode->set_attr( 'mlayer_pos', "P" );
            $cs_tnode->set_t_lemma_origin('ItTransl');

        }
        elsif ($class eq "t") {
            $cs_tnode->set_t_lemma("ten");
            $cs_tnode->set_attr( 'mlayer_pos', "P" );
            $cs_tnode->set_t_lemma_origin('ItTransl');
        }
        elsif ($class eq "n") {
            #$cs_tnode->set_t_lemma("#Gen");
            #$cs_tnode->set_t_lemma_origin('ItTransl');
            my $cs_parent = $cs_tnode->get_parent;
            $cs_parent->wild->{no_subj} = 1;
            $cs_tnode->remove();
        }
    }
#        print STDERR "PROCESS END\n";
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2CS::TrLPersPronIt

=head1 DESCRIPTION

This block handles translation of the English personal pronoun "it" into Czech.
It uses a specified classifier desribed in (Novák, Nedoluzhko, Žabokrtský, 2013)
TODO: enter the bib here
TODO: model and index should be encapsulated within a single file

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

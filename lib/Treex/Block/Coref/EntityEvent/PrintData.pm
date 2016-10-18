package Treex::Block::Coref::EntityEvent::PrintData;
use Moose;
use Treex::Core::Common;
use List::Util;

use Treex::Tool::Align::Utils;
use Treex::Tool::Coreference::Utils;
use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Coref::SupervisedBase';

has 'labeled' => ( is => 'ro', isa => 'Bool', default => 1);
has 'gold_selector' => ( is => 'ro', isa => 'Str', default => 'ref' );

sub BUILD {
    my ($self) = @_;
    $self->_feature_extractor;
    $self->_ante_cands_selector;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    # initialize global features
    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
};

sub process_filtered_tnode {
    my ( $self, $tnode ) = @_;

    return if ( $tnode->is_root );
    
    my $acs = $self->_ante_cands_selector;
    my $fe = $self->_feature_extractor;

    # in the following structure, the first array specifies the order of merged candidates in a resulting instance
    my $ee_inst_order = ["ENTITY", "EVENT"];
    my $losses = $self->labeled ? $self->get_gold_entity_event($tnode, $ee_inst_order) : undef;

    if (!$self->labeled || $losses) {
        my @cands = $acs->get_candidates($tnode);
        my @ee_cands = map {Treex::Block::Coref::EntityEvent::IndicateForCoref::is_event($_) ? "EVENT" : "ENTITY"} @cands;
        my $ee_cands_struct = [ $ee_inst_order, \@ee_cands ];
        my ($feats, $comments) = $self->get_features_comments($tnode, \@cands, $ee_cands_struct);
        my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comments);

        print {$self->_file_handle} $instance_str;
    }
}

sub get_gold_entity_event {
    my ($self, $tnode, $ee_inst_order) = @_;
    
    my ($ali_nodes, $ali_types) = $tnode->get_undirected_aligned_nodes({language => $self->language, selector => $self->gold_selector});
    my ($gold_ee_class) = grep {defined $_} map {$_->wild->{entity_event}} @$ali_nodes;

    my @losses = ( defined $gold_ee_class ? 1 : 0 );
    push @losses, map {(defined $gold_ee_class && $_ eq $gold_ee_class) ? 0 : 1} @$ee_inst_order;
    return \@losses;
}


1;

=head1 NAME

Treex::Block::Coref::PrintData

=head1 DESCRIPTION

A basic block of a train table printer for coreference resolution.
It requires the wild attribute C<gold_coref_entity> to be set.
This can be ensured by running C<Treex::Block::Coref::ProjectCorefEntities> before.

=head1 SYNOPSIS

    treex -L$lang -Ssrc
        Read::Treex from=sample.streex
        Coref::RemoveLinks type=all language=$lang
        Coref::ProjectCorefEntities selector=ref to_language=$lang to_selector=src
        Coref::PrintData language=$lang

C<Coref::PrintData> should be substituted by its subclass.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::Coref::PrintData;
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

has '_id_to_entity_id' => (is => 'rw', isa => 'HashRef');
has '_entity_id_to_mentions' => (is => 'rw', isa => 'HashRef');

sub BUILD {
    my ($self) = @_;
    $self->_feature_extractor;
    $self->_ante_cands_selector;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    my %entity_id_to_mentions = ();
    my %id_to_entity_id = ();

    my @ttrees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    foreach my $ttree (@ttrees) {
        foreach my $tnode ($ttree->get_descendants) {
            my $entity_id = $tnode->wild->{gold_coref_entity};
            if (defined $entity_id) {
                $entity_id =~ s/\?$//;
                $id_to_entity_id{$tnode->id} = $entity_id;
                if (defined $entity_id_to_mentions{$entity_id}) {
                    push @{$entity_id_to_mentions{$entity_id}}, $tnode;
                }
                else {
                    $entity_id_to_mentions{$entity_id} = [ $tnode ];
                }
            }
        }
    }
    $self->_set_id_to_entity_id(\%id_to_entity_id);
    $self->_set_entity_id_to_mentions(\%entity_id_to_mentions);
    
    # initialize global features
    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
};

sub process_filtered_tnode {
    my ( $self, $tnode ) = @_;

    return if ( $tnode->is_root );
    
    my $acs = $self->_ante_cands_selector;
    my $fe = $self->_feature_extractor;

    my @cands = $acs->get_candidates($tnode);
    my $losses = $self->labeled ? $self->is_text_coref($tnode, @cands) : undef;

    if (!$self->labeled || $losses) {
        my ($feats, $comments) = $self->get_features_comments($tnode, \@cands);
        my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, $comments);

        print {$self->_file_handle} $instance_str;
    }
}

sub is_text_coref {
    my ($self, $anaph, @cands) = @_;

    my $entity_id = $self->_id_to_entity_id->{$anaph->id};
    my $whole_chain = defined $entity_id ? $self->_entity_id_to_mentions->{$entity_id} : [];
    my %chain_hash = map {$_->id => $_} grep {$_ != $anaph} @$whole_chain;
    my @ante_cands = grep {defined $chain_hash{$_->id}} @cands;

    # if no antecedent, insert itself and if anaphor as candidate is on, it will be marked positive
    if (!@ante_cands) {
        push @ante_cands, $anaph;
    }
    my %antes_hash = map {$_->id => $_} @ante_cands;

    my @losses = map {defined $antes_hash{$_->id} ? 0 : 1} @cands;
    if (none {$_ == 0} @losses) {
        log_info "[Coref::PrintData]\tan antecedent exists but there is none among the candidates: " . $anaph->get_address;
        return;
    }
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

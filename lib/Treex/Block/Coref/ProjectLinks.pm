package Treex::Block::Coref::ProjectLinks;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
use Treex::Tool::Align::Utils;
use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

has 'to_language' => ( is => 'ro', isa => 'Str', required => 1);
has 'to_selector' => ( is => 'ro', isa => 'Str', default => '');
has 'align_type' => ( is => 'ro', isa => 'Str' );
has '_align_filter' => ( is => 'ro', isa => 'HashRef', builder => '_build_align_filter', lazy => 1 );

sub BUILD {
    my ($self) = @_;
    $self->_align_filter;
}

sub _build_align_filter {
    my ($self) = @_;
    my $af = {
        language => $self->to_language,
        selector => $self->to_selector,
    };
    if (defined $self->align_type) {
        $af->{rel_types} = [ $self->align_type ];
    }
    return $af;
}

sub process_document {
    my ($self, $doc) = @_;

    my @zones = map {$_->get_zone($self->language, $self->selector)} $doc->get_bundles;
    if (any {!defined $_} @zones) {
        log_fatal "[Treex::Block::T2T::CopyCorefFromAlignment] Zone must be specified by a language and selector.";
    }
    my @ttrees = map {$_->get_ttree} @zones;

    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees, {ordered => 'topological'});
    foreach my $chain (@chains) {
        $self->project_chain($chain);
    }
}

sub project_chain {
    my ($self, $src_chain_inverse) = @_;

    my %src_to_trg_nodes = ();
    my $covered_trg_nodes = {};

    # process chains so that the incoming nodes come first
    my @src_chain = reverse @$src_chain_inverse;
    
    my $last_src_ante = shift @src_chain;
    my $last_trg_ante = $self->get_trg_node_and_link_multiple($last_src_ante, $covered_trg_nodes);
    $src_to_trg_nodes{$last_src_ante->id} = $last_trg_ante;
    while (my $src_anaph = shift @src_chain) {
        my $trg_anaph = $self->get_trg_node_and_link_multiple($src_anaph, $covered_trg_nodes);
        $src_to_trg_nodes{$src_anaph->id} = $trg_anaph;

        if (defined $trg_anaph) {
            my @src_dir_antes = $src_anaph->get_coref_nodes;
            # if the direct antecedent has no counterpart in trg, use the last ante instead
            my @trg_dir_antes = grep {defined $_} map {$src_to_trg_nodes{$_->id}} @src_dir_antes;
            @trg_dir_antes = ($last_trg_ante // ()) if (!@trg_dir_antes);
            if (@trg_dir_antes) {
                $trg_anaph->add_coref_text_nodes(@trg_dir_antes);
            }
            
            $last_trg_ante = $trg_anaph;
        }
    }
}

sub get_trg_node_and_link_multiple {
    my ($self, $src_node, $covered_trg_nodes) = @_;
    
    my @trg_nodes = Treex::Tool::Align::Utils::aligned_transitively([$src_node], [$self->_align_filter]);
    my @new_trg_nodes = grep {!$covered_trg_nodes->{$_->id}} @trg_nodes;
    # if no alignment, nothing can be projected
    return if (!@new_trg_nodes);

    my @sorted_trg_nodes;
    push @sorted_trg_nodes, grep {$_->is_generated} @new_trg_nodes;
    push @sorted_trg_nodes, grep {!$_->is_generated} @new_trg_nodes;
    
    # if the node is aligned to more than one yet uncovered nodes, interlink them with corefence
    my $trg_anaph = shift @sorted_trg_nodes;
    $covered_trg_nodes->{$trg_anaph->id} = 1;
    while (my $trg_ante = shift @sorted_trg_nodes) {
        $trg_anaph->add_coref_text_nodes($trg_ante);
        $covered_trg_nodes->{$trg_ante->id} = 1;
        $trg_anaph = $trg_ante;
    }
    return $trg_anaph;
}


1;

=head1 NAME

Treex::Block::Coref::ProjectLinks

=head1 DESCRIPTION

This blocks projects coreference links from the current zone (src) to a zone specified by C<to_language>, 
and possibly by C<to_selector> and C<align_types> (trg).

The block processes one src coreference chain at once. Starting from the first mention, it follows over the
other mentions in an order that all antecedents of the currently processed nodes have to be already processed.
For a given mention, we try to retain direct antecedents in the projected links. However, if there is no
trg counterpart of a direct src antecedent, the last processed trg node is selected instead.
If a src mention is aligned with multiple trg nodes, the yet unprocessed are interlinked (the way of how
nodes are processed guarantees that the already visited trg counterparts are already connected to the chain).

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

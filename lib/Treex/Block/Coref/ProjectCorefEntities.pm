package Treex::Block::Coref::ProjectCorefEntities;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
use Treex::Tool::Align::Utils;
use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

has 'to_language' => ( is => 'ro', isa => 'Str', required => 1);
has 'to_selector' => ( is => 'ro', isa => 'Str', default => '');
#has 'align_type' => ( is => 'ro', isa => 'Str' );
has 'wild_attr_name' => ( is => 'ro', isa => 'Str', default => 'gold_coref_entity' );
has 'wild_attr_special_name' => ( is => 'ro', isa => 'Str', default => 'gold_coref_special' );
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
#    if (defined $self->align_type) {
#        $af->{rel_types} = [ $self->align_type ];
#    }
    return $af;
}

sub process_document {
    my ($self, $doc) = @_;

    my @zones = map {$_->get_zone($self->language, $self->selector)} $doc->get_bundles;
    if (any {!defined $_} @zones) {
        log_fatal "[Treex::Block::T2T::CopyCorefFromAlignment] Zone must be specified by a language and selector.";
    }
    my @ttrees = map {$_->get_ttree} @zones;

    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees);
    my $entity_id = 1;
    foreach my $chain (@chains) {
        $self->project_coref_entity($chain, $entity_id);
        $entity_id++;
    }

    # set coref_special
    foreach my $ttree (@ttrees) {
        foreach my $src_tnode ($ttree->get_descendants) {
            my $coref_special = $src_tnode->get_attr("coref_special");
            next if (!defined $coref_special);
            my ($trg_nodes, $ali_types) = $src_tnode->get_undirected_aligned_nodes($self->_align_filter);
            foreach my $trg_node (@$trg_nodes) {
                # it assigns s(egm) / e(xoph) to the gold coref special wild attr
                $trg_node->wild->{$self->wild_attr_special_name} = substr($coref_special, 0, 1);
            }
        }
    }
}

sub project_coref_entity {
    my ($self, $src_chain, $entity_id) = @_;

    foreach my $src_mention (@$src_chain) {
        my ($trg_mentions, $ali_types) = $src_mention->get_undirected_aligned_nodes($self->_align_filter);
        for (my $i = 0; $i < @$trg_mentions; $i++) {
            my $trg_mention = $trg_mentions->[$i];
            if (!defined $trg_mention->wild->{$self->wild_attr_name}) {
                my $entity_str = $entity_id;
                # loosely aligned nodes can be also non-anaphoric
                if ($ali_types->[$i] eq 'monolingual.loose') {
                    $entity_str .= "?";
                }
                $trg_mention->wild->{$self->wild_attr_name} = $entity_str;
                if ( !$src_mention->get_coref_nodes ) {
                    $trg_mention->wild->{$self->wild_attr_special_name} .= "f";
                }
            }
        }
    }
}


1;

=head1 NAME

Treex::Block::Coref::ProjectCorefEntities

=head1 DESCRIPTION

This blocks projects coreference entities and some additional coreference properties.
All information is stored in two wild attributes, whose names are specified by the
C<wild_attr_name> and C<wild_attr_special_name> attributes.

=head1 ATTRIBUTES

=over

=item wild_attr_name

The entity number is stored as a wild attribute under the name specified here.
Used in isolation it has no meaning, however, one can collect all the mentions from the same entity
by including all mentions sharing the same number.
It can be followed by a question mark, meaning that this entity is projected through
the loose monolungual alignment. Both options - assigning them to the specified entity cluster or
declaring them non-anaphoric - are correct for resolution on such mentions.

=item wild_attr_special_name

Additional coreference properties are stored as a wild attribute under the name specified here.
So far, three properties can be indicated by the following letters or their combination:
C<f> - first mention of the coreference entity (chain)
C<s> - mention referring to a segment
C<e> - exophoric mention

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::Coref::ProjectCorefEntities;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
use Treex::Tool::Align::Utils;
use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

subtype 'BridgTypesHash' => as 'HashRef[Bool]';
coerce 'BridgTypesHash'
    => from 'Str'
    => via { my @a = split /,/, $_; my %hash; @hash{@a} = (1) x @a; \%hash };

# TODO: move other ("f", "s", "e") special flags to wild_attr_name and cancel wild_attr_special_name
# so far, only "?" (loose monolingual alignment) and "c" (coordination member) used there
# TODO: is it possible to use ProjectCorefEntities before SimpleEval or EntityEventEval?
# all the modifications would need to be done only at a single place

has 'to_language' => ( is => 'ro', isa => 'Str', required => 1);
has 'to_selector' => ( is => 'ro', isa => 'Str', default => '');
#has 'align_type' => ( is => 'ro', isa => 'Str' );
has 'wild_attr_name' => ( is => 'ro', isa => 'Str', default => 'gold_coref_entity' );
has 'wild_attr_special_name' => ( is => 'ro', isa => 'Str', default => 'gold_coref_special' );
has 'bridg_as_coref' => ( is => 'ro', isa => 'BridgTypesHash', coerce => 1, default => '' );
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

    my %all_processed = ();


    # project source coreference chains
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees, { bridg_as_coref => $self->bridg_as_coref });
    my $entity_id = 1;
    foreach my $chain (@chains) {
        my @processed = $self->project_coref_entity($chain, $entity_id);
        $all_processed{$_->id}++ foreach (@processed);
        $entity_id++;
    }

    # project singletons that correspond to multiple coreferential mentions in the target zone
    foreach my $ttree (@ttrees) {
        foreach my $src_tnode ($ttree->get_descendants) {
            next if ($all_processed{$src_tnode->id});
            my ($trg_tnodes, $ali_types) = $src_tnode->get_undirected_aligned_nodes($self->_align_filter);
            next if (@$trg_tnodes < 2 && !any {$_ eq 'monolingual.loose'} @$ali_types);
            for (my $i = 0; $i < @$trg_tnodes; $i++) {
                $self->_project_to_node($src_tnode, $trg_tnodes->[$i], $ali_types->[$i], $entity_id);
            }
            $entity_id++;
        }
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
    
    # disambiguate multiple projected entities
    my @trg_ttrees = map {$_->get_tree($self->to_language, 't', $self->to_selector)} $doc->get_bundles;
    foreach my $trg_ttree (@trg_ttrees) {
        foreach my $trg_tnode ($trg_ttree->get_descendants) {
            if (defined $trg_tnode->wild->{$self->wild_attr_name}) {
                my @all_entities = split /,/, $trg_tnode->wild->{$self->wild_attr_name};
                my ($entity) = uniq grep {$_ !~ /\?/} @all_entities;
                if (!defined $entity) {
                    ($entity) = @all_entities;
                }
                $trg_tnode->wild->{$self->wild_attr_name} = $entity;
                #printf STDERR "%s\t%s\n", $trg_tnode->wild->{$self->wild_attr_name}, $trg_tnode->get_address;
            }
        }
    }
}

sub project_coref_entity {
    my ($self, $src_chain, $entity_id) = @_;

    my @processed = ();

    foreach my $src_mention (@$src_chain) {
        push @processed, $src_mention;
        my ($trg_mentions, $ali_types) = $src_mention->get_undirected_aligned_nodes($self->_align_filter);
        for (my $i = 0; $i < @$trg_mentions; $i++) {
            $self->_project_to_node($src_mention, $trg_mentions->[$i], $ali_types->[$i], $entity_id);
        }
        # if the source mention is a coord root with no target counterpart
        # set the entity id to counterparts of its members and set a flag indicating that the equivalence is not pure
        if (!@$trg_mentions && $src_mention->is_coap_root && $src_mention->functor ne "APPS") {
            foreach my $src_member ($src_mention->get_coap_members) {
                push @processed, $src_member;
                my ($trg_members, $ali_member_types) = $src_member->get_undirected_aligned_nodes($self->_align_filter);
                for (my $i = 0; $i < @$trg_members; $i++) {
                    $self->_project_to_node($src_mention, $trg_members->[$i], $ali_member_types->[$i], $entity_id);
                    $trg_members->[$i]->wild->{$self->wild_attr_name} .= "c";
                }
            }
        }
    }

    return @processed;
}

sub _project_to_node {
    my ($self, $src_node, $trg_node, $ali_type, $entity_id) = @_;
    my $entity_str = defined $trg_node->wild->{$self->wild_attr_name} ? ($trg_node->wild->{$self->wild_attr_name} . ",") : "";
    
    $entity_str .= $entity_id;
    # loosely aligned nodes can be also non-anaphoric
    if ($ali_type eq 'monolingual.loose') {
        $entity_str .= "?";
    }
    $trg_node->wild->{$self->wild_attr_name} = $entity_str;
    if ( !$src_node->get_coref_nodes && $ali_type ne 'monolingual.loose' ) {
        $trg_node->wild->{$self->wild_attr_special_name} .= "f";
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

package Treex::Block::W2A::AnalysisWithAlignedTrees;

use strict;
use warnings;

# TODO: rename once the role of this block is absolutely clear
# (it is something like things that both LabelMIRA and ParseMSTperl need
# to work with parallel attributes)
# And now it is even worse as it also ensures truncating Czech lemmas...
# it is something like MSTperlAttributeHelper

use Moose::Role;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use Treex::Tool::Parser::MSTperl::Node;

# use features from aligned tree
has 'use_aligned_tree' => ( isa => 'Bool', is => 'ro', default => '0' );

# the language of the tree which is already parsed and is accessed via the
# 'aligned_' prefix, eg. en
has 'alignment_language' => ( isa => 'Str', is => 'ro', default => 'en' );

# alignment type to use, eg. 'int' or 'int.gdfa'
# (see Align::A::InsertAlignmentFromFile/symmetrizations)
has 'alignment_type' => ( isa => 'Str', is => 'ro', default => 'int.gdfa' );

# use alignment info from the other tree
has 'alignment_is_backwards' => ( isa => 'Bool', is => 'ro', default => '1' );

# get alignment mapping:
# CURRENT VERSION:
#   $alignment_hash->{node_id} = aligned_node
#   (if there are multiple aligned nodes, the first one is used)
# PREVIOUS VERSION:
#   $alignment_hash->{node_id} = [aligned_node1, aligned_node2, ...]
sub _get_alignment_hash {
    my ( $self, $bundle ) = @_;

    my $alignment_hash;
    if ( $self->use_aligned_tree && $self->alignment_is_backwards ) {

        # we need to provide the other direction of the relation
        $alignment_hash = {};

        # gets root of aligned Analytical tree
        my $aligned_root =
            $bundle->get_tree( $self->alignment_language, 'A' );

	my @aligned_nodes = $aligned_root->get_descendants;

        # foreach node in the aligned-language tree
        foreach my $aligned_node ( @aligned_nodes ) {
            my $node = $self->_get_aligned_node($aligned_node);
            if ( defined $node ) {

                # if there is a node aligned to $aligned_node,
                # store this information into $alignment_hash
                $alignment_hash->{ $node->get_attr('id') } = $aligned_node;
            }
        }
    } else {

        # Node->get_directed_aligned_nodes() will be used directly
        $alignment_hash = undef;
    }

    return $alignment_hash;
}

# get the first node aligned to $node
# with alignment of type set in $self->alignment_type
# directly using $node->get_directed_aligned_nodes()
# (or return undef)
sub _get_aligned_node {
    my ( $self, $node ) = @_;

    my $aligned_node = undef;

    my ( $aligned_nodes, $types ) = $node->get_directed_aligned_nodes();
    if ($aligned_nodes) {

        # try to find an aligned node with the right type of alignment
        for ( my $i = 0; $i < @{$aligned_nodes}; $i++ ) {
            my $current_aligned_node = $aligned_nodes->[$i];
            my $current_type         = $types->[$i];

            # alignment is of the desired type
            if ( $self->alignment_type eq $current_type ) {

                # this is the node we were looking for
                $aligned_node = $current_aligned_node;

                # we want to get the first of such nodes
                last;
            }
        }

        # now $aligned_node either has been set to a node of the right kind
        # or is still undef because there is no such node
    }    # else: there are no aligned nodes, undef will be returned

    return $aligned_node;
}

sub _get_field_value {
    my ( $self, $node, $field_name, $alignment_hash ) = @_;

    my $field_value = '';

    my ( $field_name_head, $field_name_tail ) = split( /_/, $field_name, 2 );

    # combined field (contains '_')
    if ($field_name_tail) {

        # field on aligned node(s)
        # (current version: take one aligned node at maximum)
        if ( $field_name_head eq 'aligned' ) {

            # get aligned node
            my $aligned_node = undef;
            if ( defined $alignment_hash ) {

                # get alignment from the alignment_hash
                $aligned_node = $alignment_hash->{ $node->get_attr('id') };
            } else {

                # get alignment directly from the node
                $aligned_node = $self->_get_aligned_node($node);
            }

            # get field value on the aligned node
            if ( defined $aligned_node ) {

                # if there is an aligned node, call _get_field_value on it
                $field_value =
                    $self->_get_field_value( $aligned_node, $field_name_tail );
            } else {

                # if there isn't one, return ''
                $field_value = '';
            }

            # dummy or ignored field
        } elsif ( $field_name_head eq 'dummy' ) {
            $field_value = '';

            # special field
        } else {

            # ord of the parent node
            if ( $field_name eq 'parent_ord' ) {

                # this field should be ignored in typical parsing
                # but can be used eg. in two-stage parsing
                # and is also needed for 'aligned_parent_ord'
                my $parent = $node->get_parent();
                $field_value = $parent->get_attr('ord');

            } elsif ( $field_name eq 'trunc_lemma' ) {
                # lemma without details - works only for Czech
                $field_value =
                    Treex::Tool::Lexicon::CS::truncate_lemma (
                        $node->get_attr('lemma'), 1 );

            } elsif ( $field_name eq 'coarse_tag' ) {
                # language-specific coarse grained tag
                $field_value =
                    $self->get_coarse_grained_tag( $node->get_attr('tag') );

            } elsif ( $field_name eq 'tree_distance_aligned' ) {
                $field_value =
		    $self->compute_tree_distance_aligned($node, $alignment_hash);
            } else {
                die "Incorrect field $field_name!";
            }
        }

        # ordinary field (does not contain '_')
    } else {
        $field_value = $node->get_attr($field_name);
    }

    return $field_value;
}

sub get_coarse_grained_tag {
    log_warn 'get_coarse_grained_tag should be implemented in derived classes';
    my ( $self, $tag ) = @_;

    return substr( $tag, 0, 1 );
}

# TODO: tree_distance computing basically copied from
# Treex::Block::Write::LayerAttributes::TreeDistance
# which is not a good practice -> find one best place where to have it
# and only call it from here

sub compute_tree_distance_aligned {
    my ( $self, $node, $alignment_hash ) = @_;

    # array of tree distances
    # of the node aligned to this node as the child node
    # and nodes aligned to all other nodes as parent nodes
    my @tree_distances;
    my @all_nodes =
	( $node->get_root() )->get_descendants( { ordered => 1 } );

    # get aligned node
    my $aligned_node = undef;
    if ( defined $alignment_hash ) {

	# get alignment from the alignment_hash
	$aligned_node = $alignment_hash->{ $node->get_attr('id') };
    } else {

	# get alignment directly from the node
	$aligned_node = $self->_get_aligned_node($node);
    }

    # get field value on the aligned node
    if ( defined $aligned_node ) {

	# compute the distances
	# distance to root node
	push @tree_distances, $self->_compute_tree_distance_to_root($aligned_node);
	# distances to potential parents
	foreach my $parent (@all_nodes) {
	    push @tree_distances,
	    $self->_compute_tree_distance_aligned(
		$parent, $aligned_node, $alignment_hash
		);
	}
    } else {
	# fill with zeroes
	# distance to root node
	push @tree_distances, 0;
	# distances to potential parents
	foreach my $parent (@all_nodes) {
	    push @tree_distances, 0;
	}
    }

    return join ' ', @tree_distances;
}

sub _compute_tree_distance_aligned {

    # TODO: not very effective -> make more effective
    # (at least quickly identify zeroes - they occur very often;
    # maybe it'd be better to compute the whole matrix at once...)
    my ( $self, $parent, $aligned_child, $alignment_hash ) = @_;

    # get aligned parent
    my $aligned_parent = undef;
    if ( defined $alignment_hash ) {
        # get alignment from the alignment_hash
        $aligned_parent = $alignment_hash->{ $parent->get_attr('id') };
    } else {
        # get alignment directly from the node
        $aligned_parent = $self->_get_aligned_node($parent);
    }

    # call compute_tree_distance
    my $distance = 0;
    if ( defined $aligned_parent ) {
        $distance =
            $self->compute_tree_distance( $aligned_parent, $aligned_child );
    }

    # else: keep $distance = 0

    return $distance;
}

sub compute_tree_distance {

    my ( $self, $ancestor, $descendent ) = @_;

    my $distance = 0;

    # try standard distance
    $distance =
        $self->_compute_tree_distance_1_direction( $ancestor, $descendent );
    if ( $distance == 0 ) {

        # try inversed distance
        $distance = -(
            $self->_compute_tree_distance_1_direction(
                $descendent, $ancestor
                )
        );
    }

    return $distance;
}

sub _compute_tree_distance_1_direction {

    my ( $self, $ancestor, $descendent ) = @_;

    my $ancestor_id   = $ancestor->get_attr('id');

    my $current_node = $descendent;
    my $distance     = 0;
    while (
        !$current_node->is_root()
        && $current_node->get_attr('id') ne $ancestor_id
        )
    {

        # TODO: apply 'effective' parameter
        $current_node = $current_node->get_parent();
        $distance++;
    }

    if ( $current_node->get_attr('id') ne $ancestor_id ) {

        # the $ancestor node was not found as an ancestor of $descendent node
        # i.e. the cycle stopped because $current_node->is_root()
        $distance = 0;
    }

    return $distance;
}

sub _compute_tree_distance_to_root {

    my ( $self, $descendent ) = @_;

    my $current_node = $descendent;
    my $distance     = 0;
    while ( defined $current_node && !$current_node->is_root() ) {
        # TODO: apply 'effective' parameter
        $current_node = $current_node->get_parent();
        $distance++;
    }

    return $distance;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::AnalysisWithAlignedTrees

=head1 DECRIPTION

A block which provides access to aligned trees for ParseMSTperl an LabelMIRA.

=head1 SEE ALSO

L<Treex::Block::W2A::ParseMSTperl>

L<Treex::Block::W2A::LabelMIRA>

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

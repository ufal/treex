package Treex::Block::W2A::AnalysisWithAlignedTrees;
# TODO: rename once the role of this block is absolutely clear
# (it is something like things that both LabelMIRA and ParseMSTperl need
# to work with parallel attributes)

use Moose::Role;
use Treex::Core::Common;

use Treex::Tool::Parser::MSTperl::Node;

# use features from aligned tree
has 'use_aligned_tree' => ( isa => 'Bool', is => 'ro', default => '0' );
# the language of the tree which is already parsed and is accessed via the
# 'aligned_' prefix, eg. en
has 'alignment_language' => ( isa => 'Str', is => 'ro', default => 'cs' );
# alignment type to use, eg. int.gdfa
has 'alignment_type' => ( isa => 'Str', is => 'ro', default => 'int.gdfa' );
# use alignment info from the other tree
has 'alignment_is_backwards' => ( isa => 'Bool', is => 'ro', default => '0' );


# get alignment mapping:
# CURRENT VERSION:
#   $alignment_hash->{node_id} = aligned_node
#   (if there are multiple aligned nodes, the first one is used)
# PREVIOUS VERSION:
#   $alignment_hash->{node_id} = [aligned_node1, aligned_node2, ...]
sub _get_alignment_hash {
    my ($self, $bundle) = @_;
    
    my $alignment_hash;
    if ( $self->use_aligned_tree && $self->alignment_is_backwards ) {
        # we need to provide the other direction of the relation
        $alignment_hash = {};
        # gets root of aligned Analytical tree
        my $aligned_root =
            $bundle->get_tree( $self->alignment_language, 'A' );
        # foreach node in the aligned-language tree
        foreach my $aligned_node ( $aligned_root->get_descendants ) {
            my $node = $self->_get_aligned_node($aligned_node);
            if (defined $node) {
                # if there is a node aligned to $aligned_node,
                # store this information into $alignment_hash
                $alignment_hash->{$node->id} = $aligned_node;
            }
        }
    } else {
        # Node->get_aligned_nodes() will be used directly
        $alignment_hash = undef;
    }

    return $alignment_hash;
}

# get the first node aligned to $node
# with alignment of type set in $self->alignment_type
# directly using $node->get_aligned_nodes()
# (or return undef)
sub _get_aligned_node {
    my ($self, $node) = @_;
    
    my $aligned_node = undef;
    
    my ( $aligned_nodes, $types ) = $node->get_aligned_nodes();
    if ($aligned_nodes) {
        # try to find an aligned node with the right type of alignment
        for (my $i = 0; $i < @{$aligned_nodes}; $i++) {
            my $current_aligned_node = $aligned_nodes->[$i];
            my $current_type = $types->[$i];
            # alignment is of the desired type
            if ($self->alignment_type eq $current_type) {
                # this is the node we were looking for
                $aligned_node = $current_aligned_node;
                # we want to get the first of such nodes
                last;
            }
        }
        # now $aligned_node either has been set to a node of the right kind
        # or is still undef because there is no such node
    } # else: there are no aligned nodes, undef will be returned

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
        if ($field_name_head eq 'aligned') {
            
            # get aligned node
            my $aligned_node = undef;
            if (defined $alignment_hash) {
                # get alignment from the alignment_hash
                $aligned_node = $alignment_hash->{$node->id};
            } else {
                # get alignment directly from the node
                $aligned_node = $self->_get_aligned_node($node);
            }
        
            # get field value on the aligned node
            if (defined $aligned_node) {
                # if there is an aligned node, call _get_field_value on it
                $field_value =
                    $self->_get_field_value($aligned_node, $field_name_tail);
            } else {
                # if there isn't one, return ''
                $field_value = '';
            }
            
        # dummy or ignored field
        } elsif ($field_name_head eq 'dummy') {
            $field_value = '';
        
        # special field
        } else {
            
            # ord of the parent node
            if ($field_name eq 'parent_ord') {
                # this field should be ignored in typical parsing
                # but can be used eg. in two-stage parsing
                # and is also needed for 'aligned_parent_ord'
                my $parent = $node->get_parent();
                $field_value = $parent->get_attr('ord');
            
            # language-specific coarse grained tag
            } elsif ($field_name eq 'coarse_tag') {
                $field_value =
                    $self->get_coarse_grained_tag($node->get_attr('tag'));
                
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
    
    return substr ($tag, 0, 1);
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

package Treex::Block::Depfix::CollectEdits;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );
has '+selector' => ( required => 1 );

has '+extension' => (default => '.tsv');
has '+stem_suffix' => (default => '_edits');
has '+compress' => (default => '1');

has src_alignment_type => ( is => 'rw', isa => 'Str', default => 'intersection' );
has ref_alignment_type => ( is => 'rw', isa => 'Str', default => 'monolingual' );

has config_file => ( is => 'rw', isa => 'Str', default => '' );

has fields => ( is => 'rw', isa => 'Str', default =>
    'child_lemma,child_tag,child_afun,'.
    'parent_lemma,parent_tag,parent_afun,'.
    'edge_direction,'.
    'srcchild_lemma,srcchild_tag,srcchild_afun,'.
    'srcparent_lemma,srcparent_tag,srcparent_afun,'.
    'srcedge_existence,srcedge_direction,'.
    'newchild_tag,newchild_afun,'.
    'newparent_tag,newparent_afun'
);

has fields_ar => ( is => 'rw', lazy => 1, builder => '_build_fields_ar' );

sub _build_fields_ar {
    my ($self) = @_;

    if ( $self->config_file ne '' ) {
        use YAML::Tiny;
        my $config = YAML::Tiny->new;
        $config = YAML::Tiny->read( $self->config_file );
        return $config->[0]->{fields};
    } else {
        return split /,/, $self->fields;
    }
}

use Treex::Tool::Depfix::NodeInfoGetter;

has node_info_getter => ( is => 'rw', builder => '_build_node_info_getter' );
has src_node_info_getter => ( is => 'rw', builder => '_build_src_node_info_getter' );

sub _build_node_info_getter {
    return Treex::Tool::Depfix::NodeInfoGetter->new();
}
sub _build_src_node_info_getter {
    return Treex::Tool::Depfix::NodeInfoGetter->new();
}

#has include_unchanged => ( is => 'rw', isa => 'Bool', default => 1 );

sub process_anode {
    my ($self, $child) = @_;

    my ($parent) = $child->get_eparents( {or_topological => 1} );

    my ($child_ref, $child_src, $parent_ref, $parent_src) = (
        $child->get_aligned_nodes_of_type($self->ref_alignment_type),
        $child->get_aligned_nodes_of_type($self->src_alignment_type),
        $parent->get_aligned_nodes_of_type($self->ref_alignment_type),
        $parent->get_aligned_nodes_of_type($self->src_alignment_type),
    );
    
    if (!$parent->is_root() &&
        defined $child_ref &&
        defined $parent_ref &&
        $child->lemma eq $child_ref->lemma &&
        $parent->lemma eq $parent_ref->lemma
    ) {
        
        my $info = {};
        
        # nodes info
        $self->node_info_getter->add_node_info($info, 'oldchild_',  $child);
        $self->node_info_getter->add_node_info($info, 'oldparent_', $parent);
        $self->node_info_getter->add_node_info($info, 'newchild_',  $child_ref);
        $self->node_info_getter->add_node_info($info, 'newparent_', $parent_ref);
        $self->src_node_info_getter->add_node_info($info, 'srcchild_',  $child_src);
        $self->src_node_info_getter->add_node_info($info, 'srcparent_', $parent_src);

        # edges info
        $self->node_info_getter->add_edge_info($info, 'oldedge_', $child,     $parent);
        $self->node_info_getter->add_edge_info($info, 'newedge_', $child_ref, $parent_ref);
        $self->src_node_info_getter->add_edge_info($info, 'srcedge_', $child_src, $parent_src);
    
        my @fields = map { $info->{$_}  } @{$self->fields_ar};
        print { $self->_file_handle() } (join "\t", @fields)."\n";
    }
}

1;

=head1 NAME

Treex::Block::Depfix::CollectEdits

=head1 DESCRIPTION

A Depfix block.

Collects and prints a list of performed edits, comparing the original machine
translation with the reference translation (ideally human post-editation).
To be used to get data to train Depfix.

The fields to be captured can be configured either with a comma delimited list
in C<fields>, or by a config file in C<config_file> (which has priority).
See C<sample_config.yaml> in the C<Treex::Block::Depfix> directory for a sample.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


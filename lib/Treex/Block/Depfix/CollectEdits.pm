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

has features => ( is => 'rw', isa => 'Str', default =>
    'child_lemma,child_tag,child_afun,'.
    'parent_lemma,parent_tag,parent_afun,'.
    'edge_direction,'.
    'srcchild_lemma,srcchild_tag,srcchild_afun,'.
    'srcparent_lemma,srcparent_tag,srcparent_afun,'.
    'srcedge_existence,srcedge_direction,'.
    'newchild_tag,newchild_afun,'.
    'newparent_tag,newparent_afun'
);

has features_ar => ( is => 'rw', isa => 'ArrayRef',
    lazy => 1, builder => '_build_features_ar' );

sub _build_features_ar {
    my ($self) = @_;
    
    my @features_ar = split /,/, $self->features;
    return \@features_ar;
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
        $self->add_node_info($info, 'child_',     $child,      1);
        $self->add_node_info($info, 'parent_',    $parent,     1);
        $self->add_node_info($info, 'newchild_',  $child_ref,  1);
        $self->add_node_info($info, 'newparent_', $parent_ref, 1);
        $self->add_node_info($info, 'srcchild_',  $child_src,  0);
        $self->add_node_info($info, 'srcparent_', $parent_src, 0);
        $self->add_edge_info($info, 'edge_',      $child,      $parent);
        $self->add_edge_info($info, 'srcedge_',   $child_src,  $parent_src);
    
        my @features = map { $info->{$_}  } @{$self->features_ar};
        print { $self->_file_handle() } (join "\t", @features)."\n";
    }
}

my @attributes = qw(form lemma tag afun);
my @tag_parts = qw(pos sub gen num cas pge pnu per ten gra neg voi);

sub add_node_info {
    my ($self, $info, $prefix, $anode, $splittag) = @_;

    if ( defined $anode && !$anode->is_root() ) {
        foreach my $attribute (@attributes) {
            $info->{$prefix.$attribute} = $anode->get_attr($attribute);
        }
        $info->{$prefix.'childno'} = scalar($anode->get_echildren({or_topological => 1}));
        if ( $splittag ) {
            my @tag_split = split //, $anode->tag;
            foreach my $tag_part (@tag_parts) {
                $info->{$prefix.$tag_part} = shift @tag_split;
            }
        }
    } else {
        foreach my $attribute (@attributes) {
            $info->{$prefix.$attribute} = '';
        }
        $info->{$prefix.'childno'} = '';
        if ( $splittag ) {
            foreach my $tag_part (@tag_parts) {
                $info->{$prefix.$tag_part} = '';
            }
        }
    }

    return;
}

sub add_edge_info {
    my ($self, $info, $prefix, $child, $parent) = @_;
    
    if ( !defined $child || !defined $parent ) {
        # not even the nodes exist
        $info->{$prefix.'existence'} = '';
        $info->{$prefix.'direction'} = '';
    } else {
        # direction (more of node precedence, the edge does not have to exist)
        $info->{$prefix.'direction'} = $child->precedes($parent) ? '/' : '\\';
        # existence
        my @child_parents = $child->get_eparents( {or_topological => 1} );
        my @parent_parents = $parent->get_eparents( {or_topological => 1} );
        if ( grep { $_->id eq $parent->id } @child_parents ) {
            # the edge exists
            $info->{$prefix.'existence'} = 1;
        } elsif ( grep { $_->id eq $child->id } @parent_parents ) {
            # an inverse edge exists
            $info->{$prefix.'existence'} = -1;
        } else {
            # the edge does not exist
            $info->{$prefix.'existence'} = 0;
        }
    }

    return;
}


1;

=head1 NAME

Treex::Block::Depfix::CollectEdits

=head1 DESCRIPTION

A Depfix block.

Collects and prints a list of performed edits, comparing the original machine
translation with the reference translation (ideally human post-editation).
To be used to get data to train Depfix.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


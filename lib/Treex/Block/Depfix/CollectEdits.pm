package Treex::Block::Depfix::CollectEdits;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );
has '+selector' => ( required => 1 );

has src_alignment_type => ( is => 'rw', isa => 'Str', default => 'src' );
has hpe_alignment_type => ( is => 'rw', isa => 'Str', default => 'monolingual' );

#has include_unchanged => ( is => 'rw', isa => 'Bool', default => 1 );

my $blank_node;

sub process_start {
    my ($self) = @_;

    my $blank_node_parent = Treex::Core::Node->new({
            'ord' => 0,
            form => '',
            lemma => '',
            tag => '',
            afun => '',
        });

    $blank_node = $blank_node_parent->create_child({
            'ord' => 1,
            form => '',
            lemma => '',
            tag => '',
            afun => '',
        });

    return;
}

sub process_anode {
    my ($self, $child) = @_;
    my ($parent) = $child->get_eparents();
    my ($child_hpe) = $child->get_aligned_nodes_of_type($self->hpe_alignment_type);
    my ($parent_hpe) = $parent->get_aligned_nodes_of_type($self->hpe_alignment_type);
    if (!$parent->is_root() &&
        defined $child_hpe &&
        defined $parent_hpe &&
        $child->lemma eq $child_hpe->lemma
    ) {
        # aligned src nodes
        my ($child_src) = $child->get_aligned_nodes_of_type($self->src_alignment_type);
        my ($parent_src) = $child->get_aligned_nodes_of_type($self->src_alignment_type);
        my $src_edge = -1;
        if ( defined $child_src && defined $parent_src ) {
            if ( grep { $_->id eq $parent_src->id } $child_src->get_eparents() ) {
                $src_edge = 1;
            } else {
                $src_edge = 0;
            }
        }
        if ( !defined $child_src ) {
            $child_src = $blank_node;
        }
        if ( !defined $parent_src ) {
            $parent_src = $blank_node;
        }
        
        my $edge_direction = $child->precedes($parent) ? '/' : '\\';
        my @features = (
            $child->lemma, $child->tag, $child->afun,
            $parent->lemma, $parent->tag, $parent->afun,
            $edge_direction,
            $child_src->lemma, $child_src->tag, $child_src->afun,
            $parent_src->lemma, $parent_src->tag, $parent_src->afun,
            $src_edge,
            $child_hpe->tag, $child_hpe->afun,
            $parent_hpe->tag, $parent_hpe->afun,
        );
        print { $self->_file_handle() } (join "\t", @features)."\n";
    }
}

1;

=head1 NAME

Treex::Block::Depfix::CollectEdits

=head1 DESCRIPTION

A Depfix block.

Collects and prints a list of performed edits, comparing the original machine
translation with its human post-editation.
To be used to get data to train Depfix.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


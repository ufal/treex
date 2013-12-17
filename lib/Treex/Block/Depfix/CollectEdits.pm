package Treex::Block::Depfix::CollectEdits;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );
has '+selector' => ( required => 1 );

has '+extension' => (default => '.tsv');
has '+stem_suffix' => (default => '_edits');
has '+compress' => (default => '1');

has src_alignment_type => ( is => 'rw', isa => 'Str', default => 'src' );
has ref_alignment_type => ( is => 'rw', isa => 'Str', default => 'monolingual' );

#has include_unchanged => ( is => 'rw', isa => 'Bool', default => 1 );

my $blank_node;

sub process_anode {
    my ($self, $child) = @_;
    my ($parent) = $child->get_eparents( {or_topological => 1} );
    my ($child_ref) = $child->get_aligned_nodes_of_type($self->ref_alignment_type);
    my ($parent_ref) = $parent->get_aligned_nodes_of_type($self->ref_alignment_type);
    if (!$parent->is_root() &&
        defined $child_ref &&
        defined $parent_ref &&
        $child->lemma eq $child_ref->lemma &&
        $parent->lemma eq $parent_ref->lemma
    ) {
        my $edge_direction = $child->precedes($parent) ? '/' : '\\';
        # aligned src nodes
        my ($child_src) = $child->get_aligned_nodes_of_type($self->src_alignment_type);
        my ($parent_src) = $parent->get_aligned_nodes_of_type($self->src_alignment_type);
        my $src_edge = -1;
        if ( defined $child_src && defined $parent_src ) {
            if ( grep {
                    $_->id eq $parent_src->id
                } $child_src->get_eparents( {or_topological => 1} )
            ) {
                $src_edge = 1;
            } else {
                $src_edge = 0;
            }
        }
        my ($child_src_lemma, $child_src_tag, $child_src_afun) =
            (defined $child_src)
            ?
            ($child_src->lemma, $child_src->tag, $child_src->afun)
            :
            ('', '', '');
        my ($parent_src_lemma, $parent_src_tag, $parent_src_afun) =
            (defined $parent_src)
            ?
            ($parent_src->lemma, $parent_src->tag, $parent_src->afun)
            :
            ('', '', '');
        my @features = (
            $child->lemma, $child->tag, $child->afun,
            $parent->lemma, $parent->tag, $parent->afun,
            $edge_direction,
            $child_src_lemma, $child_src_tag, $child_src_afun,
            $parent_src_lemma, $parent_src_tag, $parent_src_afun,
            $src_edge,
            $child_ref->tag, $child_ref->afun,
            $parent_ref->tag, $parent_ref->afun,
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
translation with the reference translation (ideally human post-editation).
To be used to get data to train Depfix.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


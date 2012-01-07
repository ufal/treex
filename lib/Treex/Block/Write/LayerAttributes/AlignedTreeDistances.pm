package Treex::Block::Write::LayerAttributes::AlignedTreeDistances;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';
with 'Treex::Block::W2A::AnalysisWithAlignedTrees';

has '+return_values_names' => ( default => sub { [''] } );

# has 'mode' => ( isa => enum( [ 'numeric', '3level', 'binary' ] ), is => 'ro', default => 'numeric' );

# has 'signed' => ( isa => Bool, is => 'ro', default => '1' );

# has 'effective' => ( isa => Bool, is => 'ro', default => '0' );

sub modify_single {

    my ( $self, $node, $alignment_hash ) = @_;

    my %alignment_hash_single_best;

    foreach my $key (keys %$alignment_hash) {
	$alignment_hash_single_best{$key} = $alignment_hash->{$key}->[0];
    }

    return $self->compute_tree_distance_aligned(
	$node, \%alignment_hash_single_best
	);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::LayerAttributes::AlignedTreeDistances

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::AlignedTreeDistances->new(
        mode => 'numeric'
    );

    print $modif->modify_all( $child_node );
    # prints the tree distance between the nodes

    # or in a treex scenario:

    treex \
        Write::AttributeSentencesAligned \
        language=cs alignment_language=en layer=a \
        alignment_type=int.gdfa \
        attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun \
        aligned->ord aligned->tag aligned->afun aligned->parent->ord \
        AlignedTreeDistances(node,alignment_hash)"

    # in future one will be also able to add something like
        modifier_config="{ TreeDistance => {mode => 'numeric',
            signed => '1', effective => '0'} }"

=head1 DESCRIPTION

Is a wrapper for AnalysisWithAlignedTrees


Prints an array of tree distances
of the node aligned to this node as the child node
and nodes aligned to all other nodes as parent nodes;
very similar to TreeDistance and to be smoothed somehow.

TODO: copied from TreeDistance, rewrite once it is the final version

A modifier for blocks using L<Treex::Block::Write::LayerAttributes>
which takes two L<Treex::Core::Node> arguments
(supposedly but not necessarily an ancestor and its descendent)
and returns their B<tree distance>. Distance of C<1> means that the
nodes have a parent-child relationship, distance of C<2> means that
the ancestor node is the grandparent of the descendent node, etc.

A value of C<0> means that the distance cannot be determined - either at least
one of the nodes is undefined, or the aligned nodes
are not in ancestor-descendent relationship
(they are eg. brother and sister or uncle and nephew).
(Actually, C<0> would also be returned if C<$ancestor == $descendent>
but I believe there is little reason for using it that way.)

The actual behaviour is influenced by several parameters - see below.

=head1 PARAMETERS

TODO - not implemented yet, hard-set to C<signed=1, mode=numeric, effective=0>.

=over

=item C<signed>

If C<signed> is set to C<1>, a distance lower than 0 means that
the C<$ancestor> node is in fact a descendent of the C<$descendent> node.

If C<signed> is set to C<0>, the absolute value is returned, i.e.
the result is the asme if you switch the nodes.

=item C<effective>

If C<effective> is set to C<1>, effective relations are used instead of
topological ones.

TODO: but there can be multiple effective parents to a node,
so we has to search them all!!

=item C<mode>

The mode this modifier should be working in. The allowed values are:

=over

=item C<numeric>

the actual numeric distance (absolute value)

=item C<3level>

a three-level resolution -- a direct neighbor ('near') / max. 4 nodes away ('close') / farther ('far')

=item C<binary>

just tells if the first node is a direct neighbor of the second one

=back

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

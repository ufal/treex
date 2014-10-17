package Treex::Block::A2T::ES::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkEdgesToCollapse';


# override tnode_although_aux => sub {
#     my ( $self, $node ) = @_;
# 
#     # AuxY and AuxZ are usually used for rhematizers (which should have their own t-nodes).
#     # Override: add also AuxG, so brackets and quotes have their t-nodes.
#     return 1 if $node->afun =~ /^Aux[YZ]/;
#     return 0;
# };

override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;


    # Superlative and comparative "más"
    # We are interested in the (first) effective parent.
    # If our tree-parent is a coord, the $node will collapse to this conjunction
    # and afterwards it will be distributed as aux to all members of the coordination.
    # Otherwise, our tree-parent is the same as effective parent.
    if ( $node->lemma eq 'más' ) {
        my ($eparent) = $node->get_eparents();
        return 0 if $eparent->is_root();
        return 1 if $eparent->is_adjective || $eparent->is_adverb;
    }

    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::ES::MarkEdgesToCollapse - prepare a-trees for building t-trees

=head1 DESCRIPTION

This block prepares a-trees for transformation into t-trees by filling in
two attributes: C<is_auxiliary> and C<edge_to_collapse>.
Each node marked as I<auxiliary> will not be present at the t-layer as a t-node.
It will collapse to its I<lexical> node according to C<edge_to_collapse>.
Generally, prepositions, subordinating conjunctions, and modal verbs
collapse to one of their children.
Other auxiliary nodes (aux verbs, determiners, commas,...) collapse to their parent.
Before applying this block, afun values must be filled (especially Aux* and Coord).

This block contains language specific rules for Spanish
and it is derived from L<Treex::Block::A2T::MarkEdgesToCollapse>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Gorka Labaka <gorka.labaka@ehu.es>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

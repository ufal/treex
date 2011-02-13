package Treex::Block::A2T::EN::MarkEdgesToCollapseNeg;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );

sub process_anode {
    my ( $self, $a_node ) = @_;

    # Find every word "not"
    return if $a_node->lemma ne 'not';

    # Skip nodes that are already marked to be collapsed to parent.
    # Without this check we could rarely create a t-node with no lex a-node.
    return if $a_node->edge_to_collapse;
    my ($eparent) = $a_node->get_eparents() or next;

    my $p_tag = $eparent->tag || '_root';
    my $parent_is_verb = $p_tag =~ /^(V|MD)/;
    if ( $parent_is_verb ) {
        $a_node->set_is_auxiliary(1);
        $a_node->set_edge_to_collapse(1);
    }
    return;
}

1;

=over

=item Treex::Block::A2T::EN::MarkEdgesToCollapseNeg

When building the t-layer for purposes of TectoMT transfer,
some additional rules are applied compared to preparing data for annotators.

Currently, there is just one rule for marking word "not" as auxiliary
and collapsing to the governing verb
(grammateme C<negation> will be then used also for verbs).

=back

=cut

# Copyright 2009-2011 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

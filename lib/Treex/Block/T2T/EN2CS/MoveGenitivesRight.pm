package Treex::Block::T2T::EN2CS::MoveGenitivesRight;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # reorder just genitives or prepositional groups
    return if $cs_tnode->formeme !~ /^n:([237]|.*\+\d)/;

    # don't reorder personal pronouns
    return if $cs_tnode->t_lemma eq '#PersPron';

    # don't reorder numerals (e.g. dvou žen)
    return if ($cs_tnode->get_attr('mlayer_pos') || '') eq 'C';

    # don't reorder when source formeme was not n:poss or n:attr
    my $en_tnode = $cs_tnode->src_tnode or next;
    return if $en_tnode->formeme !~ /n:(poss|attr)/;

    # don't reorder when the dependent is already in the postposition
    my ($cs_tparent) = $cs_tnode->get_parent();
    return if $cs_tparent->get_ordering_value() < $cs_tnode->get_ordering_value();

    # now we can do the reordering
    $cs_tnode->shift_after_node($cs_tparent);
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::MoveGenitivesRight

The nodes with formeme n:2, n:3, n:7 or a prepositional-group formeme,
for which the source-language formeme was n:poss or n:attr,
are moved behind the governing node.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::W2A::EN::SetIsMemberFromDeprel;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    if ($anode->is_member
        || ( $anode->conll_deprel eq 'COORD' && $anode->get_parent->tag =~ /^(CC|P)$/ )
        )
    {
        $anode->set_is_member(1);
    }
    else {
        $anode->set_is_member(0);
    }

    return 1;
}

1;

=over

=item Treex::Block::W2A::EN::SetIsMemberFromDeprel

Nodes with C<conll_deprel> attribute C<COORD>
under coordinating conjunction (tag=C) or coordinating comma (tag=P)
are marked with the C<is_member> attribute (i.e. as conjuncts).

CoNLL2007 English data marks several other constructions with COORD.
We don't consider these coordinations and therefore we don't mark these with C<is_member>.
For example:

=over

=item A rather then B

=item A along with B

=item A instead of B

=item A as much as B

=back

If C<is_member> is set before, it is preserved.

=back

=cut

# Copyright 2009-2012 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

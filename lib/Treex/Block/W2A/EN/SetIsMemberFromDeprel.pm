package Treex::Block::W2A::EN::SetIsMemberFromDeprel;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    
    if ($anode->is_member
    || ($anode->conll_deprel eq 'COORD' && $anode->get_parent->lemma ne 'rather')){
        $anode->set_is_member(1);
    } else {
        $anode->set_is_member(0);
    }

    return 1;
}

1;

=over

=item Treex::Block::W2A::EN::SetIsMemberFromDeprel

The nodes with C<conll_deprel> attribute C<COORD>
are marked with the C<is_member> attribute. No C<afun> is filled yet.
The only exception is the "rather than" construction,
which is sometimes marked with COORD in CoNLL2007 data,
but it is quite different from coordinations, so we don't mark with C<is_member>. 
If C<is_member> is set before, it is preserved.

=back

=cut

# Copyright 2009-2012 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

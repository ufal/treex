package Treex::Block::T2T::EN2CS::MoveRelClauseRight;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( $tnode->formeme =~ /rc/ ) {
        my $parent = $tnode->get_parent;
        if ( $tnode->precedes($parent) and $parent->formeme =~ /^n/ ) {
            $tnode->shift_after_subtree($parent);
        }
    }
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::MoveRelClauseRight

Relative clauses placed before their governing nouns (created e.g.
from ing-forms) are moved behing the nouns.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::T2T::EN2CS::MoveRelClauseRight;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $troot = $bundle->get_tree('TCzechT');

    foreach my $rc_head ( grep {$_->formeme =~ /rc/} $troot->get_descendants() ) {

        my $parent = $rc_head->get_parent;

        if ($rc_head->precedes($parent)
                and $parent->formeme =~ /^n/) {

            $rc_head->shift_after_subtree($parent);
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

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

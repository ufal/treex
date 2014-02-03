package Treex::Block::W2A::EN::FixConjThat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_anode {
    my ( $self, $anode ) = @_;

    if ( $anode->tag eq 'IN'
                 and $anode->precedes($anode->get_parent)
                     and $anode->get_parent->tag =~ /^V/ # TODO: possible coordinations left unresolved
                         and $anode->get_children == 0) {

        my $parent = $anode->get_parent;
        $anode->set_parent($parent->get_parent);
        $parent->set_parent($anode);
        print "rehanged\n";
    }

    return 1;
}

1;

=over

=item Treex::Block::W2A::EN::FixConjThat

If a subordinating conjunction 'that' is attached below the main verb of a subordinating clause,
then its moved above it.

=back

=cut

# Copyright 2013 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package SEnglishA_to_SEnglishT::TBLa2t_phase0;

use 5.008;
use warnings;
use strict;

use base qw(TectoMT::Block);

use TBLa2t::Common;
use TBLa2t::Common_en;

#======================================================================

sub process_document
{
    my ( $self, $document ) = @_;

    for my $bundle ( $document->get_bundles ) {
        fill_afun( $bundle->get_tree('SEnglishT') );
        repair_is_member( $bundle->get_tree('SEnglishT') );
    }
}

1;

=over

=item SEnglishA_to_SEnglishT::TBLa2t_phase0

Assumes English t-trees created with t-preprocessing by ZZ. Fills C<afun>s (with incorrect but useful values based on C<tag>, C<phrase>, and C<functions>) and repairs C<is_member>.

=back

=cut

# Copyright 2008 Vaclav Klimes

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

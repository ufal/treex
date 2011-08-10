package Treex::Block::A2A::CS::FixFIXNAME;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    if (SOMETHING_HOLDS) {

        #DO_SOMETHING

        $self->logfix1( $dep, "FIXNAME" );
        $self->regenerate_node( $gov, $g->{tag} );
        $self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixFIXNAME

Fixing FIXNAME.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::A2A::CS::FixPassiveAuxBeAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    if ( $gov->afun eq 'Pred' && $dep->afun eq 'AuxV' && $g->{tag} =~ /^Vs/ && $d->{tag} =~ /^Vp/ && ( $g->{gen} . $g->{num} ne $d->{gen} . $d->{num} ) ) {
        my $new_gn = $g->{gen} . $g->{num};
        $d->{tag} =~ s/^(..)../$1$new_gn/;

        $self->logfix1( $dep, "PassiveAuxBeAgreement" );
        $self->regenerate_node( $dep, $d->{tag} );
        $self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixPassiveAuxBeAgreement

Fixing agreement between pasive and auxiliary verb 'to be'.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

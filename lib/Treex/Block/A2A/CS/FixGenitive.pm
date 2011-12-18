package Treex::Block::A2A::CS::FixGenitive;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

# not tested much, seems it never fires for some reason

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    # genitival construction

    if (
#	$g->{tag} =~ /^N/ &&
	$d->{tag} =~ /^N/ &&
	$d->{tag} !~ /^....2/ &&
	# $en_counterpart{$gov} &&
	$en_counterpart{$dep} &&
	$en_counterpart{$dep}->get_eparents({first_only=>1, or_topological => 1}) &&
	($en_counterpart{$dep}->get_eparents({first_only=>1, or_topological => 1}))->form eq 'of'
	) {

        #set dependent case to genitive
	my $case = 2;
	$d->{tag} =~ s/^(....)./$1$case/;

        $self->logfix1( $dep, "Genitive" );
        $self->regenerate_node( $dep, $d->{tag} );
        $self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixGenitive

Fixing genitive (eg. English "village of dwarves" = "vesnice trpaslíků") - 
the case is "2" in Czech.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

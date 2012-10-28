package Treex::Block::A2A::CS::FixSubjectPredicateAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ($self->en($dep)
        && $self->en($dep)->afun && $self->en($dep)->afun eq 'Sb'
        && $g->{tag} =~ /^VB/ && $d->{tag} =~ /^[NP]/
        && $dep->form !~ /^[Tt]o$/
        && ( $d->{case} eq '1' )
        && $g->{num} ne $d->{num}
        )
    {
        my ( $enDep, $enGov, $enD, $enG ) = $self->get_pair( $self->en($dep) );
        if ( $self->en($gov) && $enGov && $self->en($gov)->id ne $enGov->id ) {
            return;
        }

        # g num <- d num
        substr $g->{tag}, 3, 1, $d->{num};
        if ( $d->{pers} =~ /[123]/ ) {

            # g pers <- d pers
            substr $g->{tag}, 7, 1, $d->{pers};
        }
        $self->logfix1( $dep, "SubjectPredicateAgreement" );
        $self->regenerate_node( $gov, $g->{tag} );
        $self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixSubjectPredicateAgreement

Fixing agreement between subject and predicate.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

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

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixSubjectPredicateAgreement

=head1 DESCRIPTION

Fixing agreement between subject and predicate.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz> 

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.

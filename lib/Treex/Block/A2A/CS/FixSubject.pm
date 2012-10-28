package Treex::Block::A2A::CS::FixSubject;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    # if ($self->en($dep) && $self->en($dep)->afun eq 'Sb' && $d->{case} ne '1') {
    # if ($dep->afun eq 'Sb' && $d->{case} ne '1') {
    # if ($dep->afun eq 'Sb' && $d->{case} ne '1' && $dep->ord < $gov->ord) {
    if ($dep->afun eq 'Sb'
        && $d->{case} ne '1'
        && $d->{case} ne '-'
        && $self->en($dep)
        && (( $self->en($dep)->afun && $self->en($dep)->afun eq 'Sb' )
            || $self->en($dep)->get_eparents(
                {
                    first_only                      => 1,
                    or_topological                  => 1,
                    ignore_incorrect_tree_structure => 1
                }
            )->form eq 'by'
        )
        )
    {

        my $case = '1';
        $d->{tag} =~ s/^(....)./$1$case/;

        if ( $d->{num} eq 'S' ) {

            # maybe correct form, only incorrectly tagged
            $d->{tag} = $self->try_switch_num(
                $dep->form, $dep->lemma, $d->{tag}
            );
        }

        $self->logfix1( $dep, "Subject" );
        $self->regenerate_node( $dep, $d->{tag} );
        $self->logfix2($dep);
    }
}

1;

=over

=item Treex::Block::A2A::CS::FixSubject

Fixing Subject case and number.

=back

=cut

# Copyright 2011 David Marecek, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

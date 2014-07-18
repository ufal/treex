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
    if ($dep->afun
        && $dep->afun eq 'Sb'
        && $d->{case} ne '1'
        && $d->{case} ne '-'
        && $self->en($dep)
        && (( $self->en($dep)->afun && $self->en($dep)->afun eq 'Sb' )
            || ($self->en($dep)->parent() && eval { $self->en($dep)->get_eparents(
                {
                    first_only                      => 1,
                    or_topological                  => 1,
                    ignore_incorrect_tree_structure => 1
                }
            )->form eq 'by' } ) # eval used to catch errors in case that ->form is undef
        )
        )
# TODO: very rarely I am getting:
# Use of uninitialized value in string eq at /ha/work/people/rosa/tectomt/treex/lib/Treex/Block/A2A/CS/FixSubject.pm line 19.
    {

        #my $case = '1';
        #$d->{tag} =~ s/^(....)./$1$case/;

        # if ( $d->{num} eq 'S' ) {

            # maybe correct form, only incorrectly tagged
            # $d->{tag} = $self->try_switch_num($dep, $d->{tag});
        # }

        # TODO
        my $dont_try_switch_number = $self->dont_try_switch_number;
        if ($dont_try_switch_number == 0 && $self->magic !~ /always_switch/) {
            $dont_try_switch_number = ( $self->get_node_tag_cat($dep, 'num') ne 'S' );
            log_info( $self->get_node_tag_cat($dep, 'num') . ': ' . $dont_try_switch_number );
        }

        $self->logfix1( $dep, "Subject" );
        $self->set_node_tag_cat($dep, 'case', 1);
        $self->regenerate_node( $dep, $dep->tag, $dont_try_switch_number );
        $self->logfix2($dep);
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixSubject

=head1 DESCRIPTION

Fixing Subject case and number.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz> 

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.

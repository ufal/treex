package Treex::Block::A2A::CS::FixOf;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    # 'of' preposition being a head of an inflected word

    if ( !$self->en($dep) || !$self->en($dep)->parent() ) {
        return;
    }
    my $aligned_parent = $self->en($dep)->get_eparents(
        { first_only => 1, or_topological => 1 }
    );

    if (
        $g->{tag} =~ /^N/
        && $d->{tag} =~ /^[^R]...[1-7]/
        && $aligned_parent
        && $aligned_parent->form
        && $aligned_parent->form eq 'of'
        && !$self->isName($dep)
        && !$self->isTimeExpr( $self->en($dep)->lemma )
        )
    {

        # now find the correct case and number for this situation
        my $original_case = $d->{case};
        my $new_case      = 2;

        if ( $new_case != $original_case ) {

            # change old case to new case
            # $d->{tag} = $self->try_switch_num($dep, $d->{tag});

            $self->logfix1( $dep, "Of" );
            $self->set_node_tag_cat($dep, 'case', $new_case);
            $self->regenerate_node($dep);
            $self->logfix2($dep);
        }

    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixOf

=head1 DESCRIPTION

The English preposition 'of' is often translated into Czech by using the
genitive case (if a preposition is not used).

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.


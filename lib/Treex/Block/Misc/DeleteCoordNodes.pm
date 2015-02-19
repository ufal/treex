package Treex::Block::Misc::DeleteCoordNodes;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'attach_below_1st' => ( isa => 'Bool', is => 'ro', default => 0 );

has 'delete_conj' => ( isa => 'Bool', is => 'ro', default => 1 );

sub process_tnode {
    my ( $self, $tnode ) = @_;

    return if ( !$tnode->is_coap_root );
    my $tpar      = $tnode->get_parent();
    my @tchildren = $tnode->get_children();

    my $tattach = $tpar;

    if ( $self->attach_below_1st ) {
        my ($tfirst_member) = first { $_->is_member } @tchildren;
        if ($tfirst_member) {
            $tattach = $tfirst_member;
        }
    }

    for ( my $i = 0; $i < @tchildren; ++$i ) {
        if ( !$tchildren[$i]->is_member ) {
            my @cands = ();
            if ( $i < @tchildren - 1 ) {
                push @cands, @tchildren[ $i .. scalar(@tchildren) - 1 ];
            }
            if ( $i > 0 ) {
                push @cands, reverse @tchildren[ 0 .. $i - 1 ];
            }
            my ($tmember) = first { $_->is_member } @cands;
            $tchildren[$i]->set_parent( $tmember ? $tmember : $tattach );
        }
        else {
            $tchildren[$i]->set_parent( $tchildren[$i] == $tattach ? $tpar : $tattach );
        }
    }

    if ( $self->delete_conj ) {
        $tnode->remove();
    }
    else {
        $tnode->set_parent($tattach);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Misc::DeleteCoordNodes

=head1 DESCRIPTION

Simplifying coordinations for the Tgen generator (training data).

=head1 PARAMETERS

=over

=item attach_below_1st

If true, the 1st coordinand will be the head and the rest will hang under it (Stanford-style).

=item delete_conj

If true, the conjunction node will be deleted.

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

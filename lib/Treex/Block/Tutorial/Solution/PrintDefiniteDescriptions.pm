############################################################################
# SPOILER ALERT:                                                           #
# This is a solution of Treex::Block::Tutorial::PrintDefiniteDescriptions  #
############################################################################

package Treex::Block::Tutorial::Solution::PrintDefiniteDescriptions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has task => (
    is            => 'ro',
    isa           => enum( [qw(A B C)] ),
    default       => 'A',
    documentation => 'What task (A, B or C) should be done',
);

sub process_anode {
    my ( $self, $anode ) = @_;

    # Select only nodes ($anode) representing the definite article,
    # i.e. exit this method if the lowercased form of $anode is not "the".
    return if lc( $anode->form ) ne 'the';

    # Let $parent be the governing node of "the".
    my $parent = $anode->get_parent();

    my @description_nodes = ();

    # TASK A:
    if ( $self->task eq 'A' ) {
        @description_nodes =
            grep { $anode->precedes($_) }
            $parent->get_descendants( { preceding_only => 1 } );

        # TASK A (alternative solution)
        # @description_nodes =
        #     grep { $anode->precedes($_) && $_->precedes($parent)}
        #     $parent->get_descendants( { ordered => 1 } );

    }

    # TASK B:
    elsif ( $self->task eq 'B' ) {

        @description_nodes =
            grep { $anode->precedes($_) }
            $parent->get_children( { preceding_only => 1 } );
    }

    # TASK C:
    else {
        @description_nodes =
            grep { $anode->precedes($_) }
            $parent->get_children( { preceding_only => 1 } );

        # Exit the whole method if there is no (nested) structure.
        my $has_structure = any { $_->get_children() } @description_nodes;
        return if !$has_structure;
    }

    # Print the whole sentence (useful for debugging)
    print 'SENT: ' . $anode->get_zone()->sentence . "\n";

    # Print the definite description
    print 'DESC: ';
    print join ' ', map { $_->form } ( $anode, @description_nodes, $parent );
    print "\n";

    # Print the address of $parent (useful for TrEd output)
    print $parent->get_address() . "\n";

    return;
}

1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::Solution::PrintDefiniteDescriptions

=head1 DESCRIPTION

Definite descriptions are one of the most common constructs in English.
This block approximates definite description in analytical trees as
sequences of tokens starting from "the" and ending with the determiner's
governing node.
Three variants are implemented, see parameter C<task>.

=head1 PARAMETERS

=head2 task

Users can specify three values for this block parameter: A, B or C.

A is the default and it prints the whole definite description.

B does not print possible nested phrases in the description.

C prints only such descriptions which are missing nested phrases.


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

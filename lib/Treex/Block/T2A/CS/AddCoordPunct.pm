package Treex::Block::T2A::CS::AddCoordPunct;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    my ( $my_lemma, $last_lemma ) = ( '', '' );
    foreach my $anode (@anodes) {
        $last_lemma = $my_lemma;
        $my_lemma   = $anode->lemma;
        next if ( $anode->afun || '' ) ne 'Coord';
        my @children = $anode->get_children( { ordered => 1 } ) or next;

        # 1. Comma in front of the coordination node
        # In Czech only for "ale" (but) and sometimes "nebo" (or)
        # TODO čárka před nebo ve vylučovacím významu
        # TODO $last_lemma ne ',' seems to be unnecessary
        if ( $my_lemma =~ /^(ale|ani)$/ && $last_lemma ne ',' ) {
            my $punct = add_comma_node($anode);
            $punct->shift_before_node($anode);
        }

        # 2. Comma between conjunct
        # Let's have e.g.: A B C $anode D
        # then we want to put commas in front of B and C subtrees.
        # Although it is possible that some commas are needed also
        # after the $anode (A, B and C, D), it's more probably wrong parsing
        # where C should depend on D.
        my ( undef, @members_before_coord ) =
            grep { $_->is_member && $_->precedes($anode) } @children;

        foreach my $conjunct (@members_before_coord) {
            my $punct = add_comma_node($anode);
            $punct->shift_before_subtree($conjunct);
        }
    }

    return;
}

sub add_comma_node {
    my ($parent) = @_;
    return $parent->create_child(
        {   'form'          => ',',
            'lemma'         => ',',
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
}

1;

=over

=item Treex::Block::T2A::CS::AddCoordPunct

Add a-nodes corresponding to commas in front of 'ale'
and also commas in multiple coordinations (A, B, C a D).

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

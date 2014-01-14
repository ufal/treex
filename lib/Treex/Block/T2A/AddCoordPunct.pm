package Treex::Block::T2A::AddCoordPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    my ($prev_anode) = undef;

    foreach my $anode (@anodes) {

        next if ( $anode->afun || '' ) ne 'Coord';
        my @children = $anode->get_children( { ordered => 1 } ) or next;

        # 1. Comma between multiple conjuncts
        # Let's have e.g.: A B C $anode D
        # then we want to put commas in front of B and C subtrees.
        # Although it is possible that some commas are needed also
        # after the $anode (A, B and C, D), it's more probably wrong parsing
        # where C should depend on D.
        my ( undef, @members_before_coord ) =
            grep { $_->is_member && $_->precedes($anode) } @children;

        foreach my $conjunct (@members_before_coord) {
            my $punct = $self->add_comma_node($anode);
            $punct->shift_before_subtree($conjunct);
        }

        # 2. Comma in front of the coordination word itself
        if ( $self->comma_before_conj( $anode, $prev_anode, \@members_before_coord ) ) {
            my $punct = $self->add_comma_node($anode);
            $punct->shift_before_node($anode);
        }

        $prev_anode = $anode;
    }

    return;
}

sub add_comma_node {
    my ( $self, $parent ) = @_;
    return $parent->create_child(
        {   'form'          => ',',
            'lemma'         => ',',
            'afun'          => 'AuxX',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
}

# Indicates whether to put a comma befor the given conjunction node. To be overridden by child blocks.
sub comma_before_conj {
    my ( $self, $conj_anode, $prev_anode, $members_rf ) = @_;
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddCoordPunct

=head1 DESCRIPTION

Add a-nodes corresponding to commas in coordinations
(of clauses as well as words/phrases).

Commas are always added to separate items of lists with 3 and more members
where the conjunction is not present, language-specific code ( comma_before_conj )
is required to determine the placement of a comma directly in front of the conjunction.

This block contains language-independent code, it is to be overridden
for individual languages.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

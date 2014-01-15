package Treex::Block::T2A::EN::AddCoordPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddCoordPunct';

override 'comma_before_conj' => sub {
    my ( $self, $conj_anode, $prev_anode, $members_rf ) = @_;

    # at least 3 coordinated members
    return 1 if ( $#{$members_rf} >= 3 );

    # must be coordinating conjunction connecting clauses
    return 0 if ( ( $conj_anode->lemma // '' ) !~ /^(and|but|for|or|nor|so|yet)$/ );

    # must be connecting two different clauses
    my ($preceding_node) = first { $_->precedes($conj_anode) } reverse @$members_rf;
    my ($following_node) = first { $conj_anode->precedes($_) } @$members_rf;
    return 0 if ( $preceding_node->clause_number == $following_node->clause_number );

    # a subject must be repeated in last clause
    return 0 if ( not any { ( $_->afun // '' ) eq 'Sb' } $following_node->get_echildren() );

    return 1;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddSubordClausePunct

=head1 DESCRIPTION

Add a-nodes corresponding to commas in coordinations
(of clauses as well as words/phrases).

English-specfic: Add a comma node if the number of coordinated members
is 3 or more or if coordinating two clauses where the subject is repeated in the second one. 

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

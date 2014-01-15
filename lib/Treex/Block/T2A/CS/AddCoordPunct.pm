package Treex::Block::T2A::CS::AddCoordPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddCoordPunct';

override 'comma_before_conj' => sub {
    my ( $self, $conj_anode, $prev_anode, $members_rf ) = @_;

    # In Czech only for "ale" (but) and sometimes "nebo" (or)
    # TODO čárka před nebo ve vylučovacím významu
    # TODO test for preceding comma seems to be unnecessary
    return 0 if ( ( $conj_anode->lemma // '' ) !~ /^(ale|ani)/ );
    return 0 if ( defined($prev_anode) and ( $prev_anode->lemma // '' ) eq ',' );
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

Czech-specfic: Add a-nodes corresponding to commas in front of 'ale'.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

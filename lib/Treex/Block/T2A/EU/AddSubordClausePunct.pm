package Treex::Block::T2A::EU::AddSubordClausePunct;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSubordClausePunct';

override 'no_comma_between' => sub {
    my ( $self, $left_node, $right_node ) = @_;
    return 1 if any { ( $_->afun // '' ) =~ /^(Coord|AuxC)$/ } ( $left_node, $right_node );
    return 1 if all { $_->is_member } ( $left_node, $right_node );
    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddSubordClausePunct

=head1 DESCRIPTION

Add a-nodes corresponding to commas on clause boundaries
(boundaries of relative clauses as well as
of clauses introduced with subordination conjunction).

Avoid commas before most Spanish conjunctions.

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

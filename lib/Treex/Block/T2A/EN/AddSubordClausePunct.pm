package Treex::Block::T2A::EN::AddSubordClausePunct;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSubordClausePunct';

override 'no_comma_between' => sub {
    my ( $self, $left_node, $right_node ) = @_;

    # avoid coordinations
    return 1 if any { ( $_->lemma // '' ) =~ /^(and|but|for|or|nor|so|yet)$/ } ( $left_node, $right_node );
    return 1 if any { ( $_->afun // '' ) eq 'Coord' } ( $left_node, $right_node );
    return 1 if all { $_->is_member } ( $left_node, $right_node );

    # avoid subordinate clauses following the main clause
    return 1 if $right_node->lemma =~ /^(and|or|but|either|nor|neither)$/;
    return 1 if $right_node->lemma =~ /^(after|how|till|although|if|unless|
            as|inasmuch|until|if|that|when|lest|whenever|where|provided|wherever|
            though|since|while|because|before|than|though)$/x;
    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddSubordClausePunct

=head1 DESCRIPTION

Add a-nodes corresponding to commas on clause boundaries
(boundaries of relative clauses as well as
of clauses introduced with subordination conjunction).

Avoid commas before most English conjunctions.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

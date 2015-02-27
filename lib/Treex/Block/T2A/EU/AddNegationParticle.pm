package Treex::Block::T2A::EU::AddNegationParticle;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddNegationParticle';

# to be overriden by language-specific method
override 'particle_for' => sub {
    my ($self, $t_node) = @_;

    return 'ez';
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddNegationParticle

=head1 DESCRIPTION

Add the particle of negation (e.g. 'not' in English) for nodes with gram/negation=neg1.
Place the particle before the node.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

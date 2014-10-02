package Treex::Block::T2A::NL::AddInfinitiveParticles;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddInfinitiveParticles';

override 'works_as_conj' => sub {
    my ($self, $particle) = @_;
    return not $particle eq 'te';
}; 

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::AddInfinitiveParticles

=head1 DESCRIPTION

Particles 'om-te' and others are added before Dutch infinitives.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

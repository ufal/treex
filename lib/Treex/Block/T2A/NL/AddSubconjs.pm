package Treex::Block::T2A::NL::AddSubconjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::EN::AddSubconjs';

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::AddSubconjs

=head1 DESCRIPTION

Add a-nodes corresponding to subordinating conjunctions
(according to the corresponding t-node's formeme).

This actually reuses the code from the English block as the 
behavior is same in Dutch. 

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

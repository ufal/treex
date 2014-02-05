package Treex::Block::T2A::CS::DeleteSuperfluousAuxCP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::DeleteSuperfluousAuxCP';

has '+override_distance_limit' => (
    default => sub {
        {
            'v'        => 5,
            'mezi'     => 50,
            'pro'      => 8,
            'protože' => 5,
        }
    },
);

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::DeleteSuperfluousAuxCP

=head1 DESCRIPTION

Removing superfluous prepositions or conjunctions in coordinations. 

This is just a Czech-specific setting for L<Treex::Block::T2A::DeleteSuperfluousAuxCP>.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::A2A::CS::VocalizePrepos;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::CS::VocalizePrepos';

override 'is_prep' => sub {
    my ($self, $anode) = @_;

    return $anode->tag =~ /^R/;
};

1;

=head1 NAME 

Treex::Block::A2A::CS::VocalizePrepos

=head1 DESCRIPTION

An a-layer version of L<Treex::Block::T2A::CS::VocalizePrepos>.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

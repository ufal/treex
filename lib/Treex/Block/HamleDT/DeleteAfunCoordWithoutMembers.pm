package Treex::Block::HamleDT::DeleteAfunCoordWithoutMembers;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    return if $anode->afun ne 'Coord';
    return if any {$_->is_member} $anode->get_children();
    $anode->set_afun('NR');
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::DeleteAfunCoordWithoutMembers - fix inconsistent coordinations

=head1 DESCRIPTION

If a node is marked with afun=C<Coord>, but there are no conjuncts (is_member=1)
among its children, then the afun is changed to C<NR> (not recognized).
This approximation is useful for situations when
the is_member attribute is more reliable than afun.

=head1 SEE ALSO

L<Treex::Block::HamleDT::SetAfunCoordAboveMembers>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::A2A::SetAfunCoordAboveMembers;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    if ($anode->is_member and ($anode->get_parent->afun||'') !~ /Coord|Apos/) {
        $anode->get_parent->set_afun('Coord');
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::SetAfunCoordAboveMembers

=head1 DESCRIPTION

If a node is marked as a member of coordination/apposition (is_member), then
the 'Coord' value is filled into its parent afun (approximation for situations
in which the is_member attribute is more reliable than afun).

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

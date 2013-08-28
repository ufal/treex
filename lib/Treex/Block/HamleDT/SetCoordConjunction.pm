package Treex::Block::HamleDT::SetCoordConjunction;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $node ) = @_;
    delete $node->wild->{is_coord_conjunction};
    # If the tree is a result of annotation style conversion from a foreign scheme, it is possible that there is no afun at all!
    my $afun = $node->afun();
    $afun = '' if(!defined($afun));
    if ( $afun eq 'Coord' && $node->form !~ /^[,;]$/) {
        $node->wild->{is_coord_conjunction} = 1;
    }
    elsif ( $afun eq 'AuxY' ) {
        my $parent = $node->get_parent();
        return if $parent->is_root();
        return if $parent->afun ne 'Coord';
        my ( $begin, $end ) = ( $node, $parent );
        if ( $parent->precedes($node) ) {
            ( $begin, $end ) = ( $parent, $node );
        }
        my @members =
            grep { $_->is_member && $_->precedes($end) && $begin->precedes($_) }
            $parent->get_children( { ordered => 1 } );
        if (@members) {
            $node->wild->{is_coord_conjunction} = 1;
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::SetCoordConjunction - fill C<is_coord_conjunction> wild attribute in PDT-style annotation

=head1 DESCRIPTION

In the PDT style, most coordination conjunctions have afun=Coord.
However, in case of more conjunctions in one coordination, they can have also
afun=AuxY, which can be assigned also to other words (which are not conjunctions).
The attribute C<is_coord_conjunction> is a I<wild> one and you can access it by

  if ($node->wild->{is_coord_conjunction}) {...}

In other styles (e.g. Stanford) this attribute might be useful.

=head1 SEE ALSO

L<Treex::Core::WildAttr>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

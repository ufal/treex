package Treex::Block::A2A::CS::FixAuxVChildren;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;


    if ( $dep->afun eq 'AuxV' && $g->{pos} eq 'V' ) {

        my @auxv_children = $dep->get_children();
        foreach my $child (@auxv_children) {
            $self->logfix1( $child, "AuxVChildren" );
            $child->set_parent($gov);
            $self->logfix2($child);
        }

    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixAuxVChildren - move AuxV's children to its parent
verb.

=head1 DESCRIPTION

AuxV should have no children, so let's move them where they most probably
belong - under AuxV's parent.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
University in Prague


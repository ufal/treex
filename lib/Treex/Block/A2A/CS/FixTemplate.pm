package Treex::Block::A2A::CS::FixFIXNAME;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    my $endep = $self->en($dep);

    if (SOMETHING_HOLDS) {

        $self->logfix1( $dep, "FIXNAME" );
        $self->set_node_tag_cat( $gov, 'case', 4 );
        $self->regenerate_node($gov);
        $self->logfix2($dep);
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixFIXNAME

=head1 DESCRIPTION


=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

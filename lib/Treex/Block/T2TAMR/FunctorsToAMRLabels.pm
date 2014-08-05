package Treex::Block::T2TAMR::FunctorsToAMRLabels;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has '+selector' => ( isa => 'Str', default => 'amrConvertedFromT' );

my %MAPPING = (
    'ACT'   => 'ARG0',
    'PAT'   => 'ARG1',
    'ADDR'  => 'ARG2',
    'ORIG'  => 'ARG3',
    'EFF'   => 'ARG4',
    'TWHEN' => 'time',
    'THL'   => 'duration',
    'DIR1'  => 'source',
    'DIR3'  => 'direction',
    'DIR2'  => 'location',
    'LOC'   => 'location',
    'BEN'   => 'beneficiary',
    'ACMP'  => 'accompanier',
    'MANN'  => 'manner',
    'AIM'   => 'purpose',
    'CAUS'  => 'cause',
    'MEANS' => 'instrument',
    'APP'   => 'poss',
    'CMP'   => 'compared-to',
    'RSTR'  => 'mod',
    'EXT'   => 'scale',
);

sub process_tnode {

    my ( $self, $tnode ) = @_;

    my $functor = $tnode->wild->{modifier} // $tnode->functor;
    if ( !$functor and $tnode->src_tnode ) {
        $functor = $tnode->src_tnode->functor;
    }

    if ( $functor and $MAPPING{$functor} ) {
        $tnode->wild->{modifier} = $MAPPING{$functor};
    }

    return;
}

1;

=head1 NAME

Treex::Block::T2TAMR::FunctorsToAMRLabels

=head1 DESCRIPTION

Deterministically converting functors to most common corresponding AMR labels
(no valency dictionaries used).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

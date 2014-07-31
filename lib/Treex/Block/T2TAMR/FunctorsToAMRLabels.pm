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


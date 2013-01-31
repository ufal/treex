package Treex::Block::A2N::CS::SVMNER;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_zone {
    my ($self, $zone) = @_;

    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants({ordered => 1});

    my $nroot = $zone->create_ntree();

    return 1;
}


1;

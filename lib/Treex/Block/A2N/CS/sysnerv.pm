package Treex::Block::A2N::CS::SVMNER;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

my $svm;

sub process_start {

    $svm = Algorithm::SVM->new( Model => $SVM_MODEL_DIR.$ONEWORD_MODEL_FILENAME );

}



sub process_zone {
    my ($self, $zone) = @_;

    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants({ordered => 1});

    my $n_root;

    if($zone->has_ntree) {
        die "Not implemented yet";
    }
    else {
        $nroot = $zone->create_ntree();
    }



    for my $i ( 0 .. $#anodes ) {

        my ( $pprev_anode, $prev_anode, $anode, $next_anode, $nnext_anode ) = @anodes[$i-2..$i+2];

    }



    return;
}


1;

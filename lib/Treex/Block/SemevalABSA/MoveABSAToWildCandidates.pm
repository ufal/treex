package Treex::Block::SemevalABSA::MoveABSAToWildCandidates;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @nodes = $atree->get_descendants;
    my $isaspect = 0;
    my $polarity = "";
    for my $node (@nodes) {
        if ($node->{form} =~ m/^_ASPECT_START_(.*)_$/) {
            $polarity = $1;
            $isaspect = 1;
            $node->remove;
        } elsif ($node->{form} =~ m/^_ASPECT_END_$/) {
            $isaspect = 0;
            $node->remove;
        } else {
            if ($isaspect) {
                $node->wild->{absa_rules} = "bsln^$polarity";
            }
        }
    }

    return 1;
}

1;

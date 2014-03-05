package Treex::Block::SemevalABSA::MoveABSAToWild;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# sub process_anode {
#     my ( $self, $anode ) = @_;
#     if ($anode->{form} =~ m/^_(plus|minus)_(.*)_$/) {
#         $anode->wild->{absa_is_aspect} = 1;
#         $anode->wild->{absa_polarity} = $1;
#         $anode->set_form($2);
#     }
# }

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
                $node->wild->{absa_is_aspect} = 1;
                $node->wild->{absa_polarity} = $polarity;
            }
        }
    }

    return 1;
}

1;

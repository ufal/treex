package Treex::Block::Eval::CorefSegm;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $total_true_links = 0;
my $total_estim_links = 0;

sub process_bundle {
    my ($self, $bundle) = @_;

    my $true_links = $bundle->wild->{true_interlinks};
    my $true_segm_break = $bundle->wild->{true_segm_break};
    my $estim_segm_break = $bundle->wild->{estim_segm_break};

    if ($estim_segm_break) {
        $total_estim_links += $true_links;
    }
    if ($true_segm_break) {
        $total_true_links += $true_links;
    }
}

sub process_end {
    my ($self) = @_;

    print join "\t", ($total_estim_links, $total_true_links);
    print "\n";
}

1;

package Treex::Block::Eval::CorefSegm;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $total_true_naive_links = 0;
my $total_true_randomized_links = 0;
my $total_estim_links = 0;

sub process_bundle {
    my ($self, $bundle) = @_;

    my $true_links = $bundle->wild->{'true_interlinks/cs_ref'};
    my $true_naive_segm_break = $bundle->wild->{refsegm_break};
    my $true_randomized_segm_break = $bundle->wild->{ref_randomized_segm_break};
    my $estim_segm_break = $bundle->wild->{src_randomized_segm_break};

    if ($true_naive_segm_break) {
        $total_true_naive_links += $true_links;
    }
    if ($true_randomized_segm_break) {
        $total_true_randomized_links += $true_links;
    }
    if ($estim_segm_break) {
        $total_estim_links += $true_links;
    }
}

sub process_end {
    my ($self) = @_;

    print join "\t", ($total_estim_links, $total_true_naive_links, $total_true_randomized_links);
    print "\n";
}

1;

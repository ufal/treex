package Treex::Block::Segment::SetInterlinkCounts;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::InterSentLinks;


sub process_document {
    my ($self, $doc) = @_;

    my $interlinks = Treex::Tool::Coreference::InterSentLinks->new({ doc => $doc });
    my @link_counts = $interlinks->counts;

    #print STDERR Dumper(\@link_counts);

    foreach my $bundle ($doc->get_bundles) {
        my $count = shift @link_counts;
#        if ($count == 0) {
#            $bundle->wild->{segm_break} = 1;
#        }
        $bundle->wild->{true_interlinks} = $count;
    }
}

1;

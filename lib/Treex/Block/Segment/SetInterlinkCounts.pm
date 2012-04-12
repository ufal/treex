package Treex::Block::Segment::SetInterlinkCounts;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::CorefSegments::InterSentLinks;


sub process_document {
    my ($self, $doc) = @_;

    my @trees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    my $interlinks = Treex::Tool::CorefSegments::InterSentLinks->new({ 
        trees => \@trees,
    });
    my @link_counts = $interlinks->counts;

    #print STDERR Dumper($interlinks->interlinks);

    #print STDERR Dumper(\@link_counts);

    foreach my $bundle ($doc->get_bundles) {
        my $count = shift @link_counts;
#        if ($count == 0) {
#            $bundle->wild->{segm_break} = 1;
#        }

        my $label = 'true_interlinks/' . $self->language . '_' . $self->selector;

        $bundle->wild->{$label} = $count;
    }
}

1;

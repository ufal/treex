package Treex::Block::Segment::SetInterlinkCounts;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::InterSentLinks;


sub process_document {
    my ($self, $doc) = @_;

    my $interlinks = Treex::Tool::Coreference::InterSentLinks->new({ 
        doc => $doc, language => $self->language, selector => $self->selector
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

package Treex::Block::Segment::SetBlockIdsAtRandom;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $MAX_BLOCK_SIZE = 30;

sub BUILD {
    my ($self) = @_;
    srand(1986);
}

sub process_document {
    my ($self, $doc) = @_;

    my $block_len = int(rand() * $MAX_BLOCK_SIZE) + 1;
    my $block_id = 0;

    my @break_list = ();

    my $i = 0;
    my $doc_id = 0;

    foreach my $bundle ($doc->get_bundles) {
        if ($i >= $block_len) {
            push @break_list, $doc_id;
            $block_len = int(rand() * $MAX_BLOCK_SIZE) + 1;
            $block_id++;
            $i = 0;
        }
        $bundle->set_attr('czeng/blockid', $block_id);
        $i++;
        $doc_id++;
    }

    my $interlinks = Treex::Tool::Coreference::InterSentLinks->new({
        doc =>$doc, language => $self->language, selector => $self->selector,
    });
    $interlinks->remove_selected( \@break_list );

    #print STDERR "BREKAS: ";
    #print STDERR join ", ", @break_list;
    #print STDERR "\n";
    #print STDERR Dumper( $interlinks->interlinks);
}

1;

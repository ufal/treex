package Treex::Block::Segment::SetBlockIdsAtRandom;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::InterSentLinks;

my $MAX_BLOCK_SIZE = 30;
my $MAX_MISS_SENTS = 3;
my $MISS_SENTS_TO_BREAK = 3;

sub BUILD {
    my ($self) = @_;
    srand(1986);
}

sub _reconnect_corefs {
    my ($self, $bundle) = @_;

    my $tree = $bundle->get_tree($self->language, 't', $self->selector);
    foreach my $node ($tree->descendants) {
        my @coref_nodes = $node->get_coref_nodes;
        my $num = () = grep {$_->get_bundle->wild->{'to_delete'}} @coref_nodes;
        next if (!$num);

        my @coref_chain = $node->get_coref_chain;
        my $ante = shift @coref_chain;
        while (@coref_chain && ($ante->get_bundle->wild->{'to_delete'})) {
            $ante = shift @coref_chain;
        }
        if (!$ante->get_bundle->wild->{'to_delete'}) {
           $node->remove_coref_nodes( @coref_nodes );
           $node->add_coref_text_nodes( $ante );
        }
    }
}

sub process_document {
    my ($self, $doc) = @_;

    my $block_len = int(rand() * $MAX_BLOCK_SIZE) + 1;
    my $block_id = 0;

    my @break_list = ();

    my $i = 0;

    my @bundles = $doc->get_bundles;

    for (my $j = 0; $j < @bundles; $j++) {
        if ($i >= $block_len) {
            
            my $miss_sents = int(rand() * $MAX_MISS_SENTS) + 1;
            for (my $k = 0; $k < $miss_sents; $k++) {
                $bundles[$j + $k]->wild->{'to_delete'} = 1;
            }
            $j += $miss_sents;
            $bundles[$j]->set_attr("czeng/missing_sents_before", $miss_sents);
            if ($miss_sents >= $MISS_SENTS_TO_BREAK) {
                push @break_list, $j;
            }
            
            $block_len = int(rand() * $MAX_BLOCK_SIZE) + 1;
            $block_id++;
            $i = 0;
        }
        $bundles[$j]->set_attr('czeng/blockid', $block_id);

        $self->_reconnect_corefs( $bundles[$j] );

        $i++;
    }

    my @trees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    my $interlinks = Treex::Tool::Coreference::InterSentLinks->new({
        trees => \@trees,
    });
    $interlinks->remove_selected( \@break_list );

    #print STDERR "BREKAS: ";
    #print STDERR join ", ", @break_list;
    #print STDERR "\n";
    #print STDERR Dumper( $interlinks->interlinks);
}

1;

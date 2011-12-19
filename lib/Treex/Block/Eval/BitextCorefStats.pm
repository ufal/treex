package Treex::Block::Eval::BitextCorefStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::CS::PronAnaphFilter;

has 'filter' => ( 
    isa => 'Treex::Tool::Coreference::CS::PronAnaphFilter',
    is  => 'ro',
    default => sub{ return Treex::Tool::Coreference::CS::PronAnaphFilter->new },
);

sub process_tnode {
    my ($self, $tnode) = @_;

    if ($self->filter->is_candidate( $tnode )) {
        my ($nodes, $types) = $tnode->get_aligned_nodes;

        # PRINTING THE COUNT OF ALIGNED NODES
        #if (!$nodes) {
        #    print "0\n";
        #}
        #else {
        #    print (scalar @$nodes);
        #    idprint "\n";
        #}

        if (defined $nodes && (@$nodes == 1)) {
            my $en_node = $nodes->[0];
            my $lemma = $en_node->t_lemma;
            if ($lemma ne '#PersPron') {
                my $doc_id = $en_node->get_document->file_stem;
                print $lemma . ", " . $doc_id . ", " . $en_node->id . "\n";
            }

        }

        #foreach my $node (@$nodes) {
        #}
    }

}

1;

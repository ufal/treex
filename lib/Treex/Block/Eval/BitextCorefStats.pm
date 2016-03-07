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
        my ($nodes, $types) = $tnode->get_directed_aligned_nodes;

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
            
            # PRINTING LEMMAS OF 1:1 ALIGNED NODES
            # PRINTING NON-PERSPRON ALIGNED NODES
            #if ($lemma ne '#PersPron') {
            #    my $doc_id = $en_node->get_document->file_stem;
            #    print $lemma . ", " . $doc_id . ", " . $en_node->id . "\n";
            #}

            if ($lemma eq '#PersPron') {
                my @antes_align_en = map {my ($nodes, $types) = $_->get_directed_aligned_nodes; $nodes ? @$nodes : ()} $tnode->get_coref_nodes;
                my %antes_en_hash = map {$_->id => 1} $en_node->get_coref_nodes;

                my @in_common = grep {$antes_en_hash{$_->id}} @antes_align_en;
                print (scalar @in_common);
                print "\n";



            }

        }

        #foreach my $node (@$nodes) {
        #}
    }

}

1;

=over

=item Treex::Block::Eval::BitextCorefStats

Prints out the statistics of coreference in a CS-EN bitext.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
;

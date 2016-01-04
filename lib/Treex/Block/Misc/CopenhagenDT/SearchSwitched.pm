package Treex::Block::Misc::CopenhagenDT::SearchSwitched;


use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }

sub process_bundle {
    my ( $self, $bundle ) = @_;

    for my $zone ($bundle->get_all_zones) {
        my $atree = $zone->get_atree;
        for my $node ($zone->get_atree->get_descendants) {
            my ($nodes, $types) = $node->get_directed_aligned_nodes;
            next unless $nodes;
            my $following = $node->get_next_node;
            next unless $following;
            my ($f_nodes, $f_types) = $following->get_directed_aligned_nodes;
            next unless $f_nodes;

            my ($align1, $align2);
            my $id1 =100000;
            my $id2 =0;
            my $ok;
          TEST:
            for my $aligned_next (@$f_nodes) {
                for my $aligned (@$nodes) {
                    if ($aligned->precedes($aligned_next)
                        or $aligned == $aligned_next) {
                        $ok = 1;
                        last TEST;
                    }
                    else {
                      if($id1>$aligned->{wild}{id}) {$id1=$aligned->{wild}{id}; $align1 = $aligned,}
                      if($id2<$aligned_next->{wild}{id}) {$id2=$aligned_next->{wild}{id}; $align2=$aligned_next;}
                   }
                }
            }
            if (! $ok) {
                #print $node->get_address, "\n";
#                if(defined($node->tag) && defined($following->tag)) { print $node->tag, ' ', $following->tag, "\n";}
#                if(defined($node->form) && defined($following->form)) { 
#                   printf "%s_%s\t%s_%s\t%s\n", $node->form, $following->form, $align2->form, $align1->form, $id1-$id2;
#                }
                $atree->{wild}{searchFeatures}{$id1}{discont}{n1} = $node;
                $atree->{wild}{searchFeatures}{$id1}{discont}{n2} = $following;
                $atree->{wild}{searchFeatures}{$id1}{discont}{a1} = $align1;
                $atree->{wild}{searchFeatures}{$id1}{discont}{a2} = $align2;
            }
        }
    }
}



1;

=over

=item Treex::Block::Misc::CopenhagenDT::SearchSwitched

Reports positions of all the nodes in all the zones, if the node is
followed by a node, but they are aligned to nodes with switched order.

=back

=cut

# Copyright 2012 Jan Stepanek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

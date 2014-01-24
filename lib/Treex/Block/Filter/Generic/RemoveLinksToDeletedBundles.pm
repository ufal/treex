package Treex::Block::Filter::Generic::RemoveLinksToDeletedBundles;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    # skip bundles to delete
    return if ($bundle->wild->{'to_delete'});

    foreach my $zone (grep {$_->has_ttree} $bundle->get_all_zones) {
        my $tree = $zone->get_ttree;

        foreach my $t_node ($tree->descendants) {
            
            # find out if the node points to a bundle to be removed
            my @coref_nodes = $t_node->get_coref_nodes;
            my $num = () = grep {$_->get_bundle->wild->{'to_delete'}} @coref_nodes;
            
            # skip the nodes with correct links
            next if (!$num);

            # find the first antecedent in the chain, which isn't going to be removed
            my @coref_chain = $t_node->get_coref_chain;
            my $ante = shift @coref_chain;
            while (@coref_chain && ($ante->get_bundle->wild->{'to_delete'})) {
                $ante = shift @coref_chain;
            }
            
            # remove links pointing out from this node
            $t_node->remove_coref_nodes( @coref_nodes );
            # add a distant but in-the-same-chain antecedent
            if (!$ante->get_bundle->wild->{'to_delete'}) {
               $t_node->add_coref_text_nodes( $ante );
               print STDERR "COREF: " . $t_node->id . "\n";
            }
            
            # remove from deleted
            #if ($bundle->wild->{'to_delete'}) {
            #    $t_node->remove_coref_nodes( @antes );
            #}

        }
    }


}

1;

=over

=item Treex::Block::Filter::Generic::RemoveLinksToDeletedBundles

Removes all coreferential links from attributes 'coref_gram.rf' and 'coref_text.rf',
which point to the bundles, which are no longer present.

=back

=cut

# Copyright 2011, 2014 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

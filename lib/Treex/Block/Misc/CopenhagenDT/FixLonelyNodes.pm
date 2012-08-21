package Treex::Block::Misc::CopenhagenDT::FixLonelyNodes;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }


sub process_document {
    my ( $self, $document ) = @_;

    my @bundles = $document->get_bundles;
    my $first_bundle = shift @bundles;


  ZONE:
    foreach my $zone ($first_bundle->get_all_zones) {

        my $language = $zone->language;

      LONELY_NODE:
        foreach my $lonely_node ( $zone->get_atree->get_children ) {

            my $linenumber = $lonely_node->wild->{linenumber};

            my $prev_node;

          BUNDLE:
            foreach my $bundle (@bundles) {
                my $zone = $bundle->get_zone($language);
                next BUNDLE if not defined $zone;

                foreach my $node ($zone->get_atree->get_descendants) {

                    if ( $node->wild->{linenumber} > $linenumber ) {

                        if (defined $prev_node and $lonely_node->wild->{sent_number}
                                == $prev_node->wild->{sent_number}) {
                            $lonely_node->set_parent($prev_node->get_root);
                            $lonely_node->shift_after_node($prev_node);
                        }

                        else {
                            $lonely_node->set_parent($node->get_root);
                            $lonely_node->shift_before_node($node);
                        }
                        next LONELY_NODE;
                    }
                    $prev_node = $node;
                }
            }

            if (defined $prev_node) { # if the lonely node was the very last in the file
                $lonely_node->set_parent($prev_node->get_root);
                $lonely_node->shift_after_node($prev_node);
            }

            log_warn "Lonely node was not moved, as no nodes were found in successive bundles.";

        }
    }

    return;
}


1;

=over

=item Treex::Block::Misc::CopenhagenDT::FixLonelyNodes

Nodes (or small subtrees) that remained in the first bundle
probably result from a wrong annotation (they don't have a parent,
otherwise they would have been moved). Now each such node is moved
behind the node with nearest lower linenumber.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

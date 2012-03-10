package Treex::Block::Misc::CopenhagenDT::BuildTreesFromOffsetIndices;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $zone ($bundle->get_all_zones) {

        my $a_root = $zone->get_atree();
        my @nodes = $a_root->get_descendants;

        foreach my $node_index (0..$#nodes) {
            my $node = $nodes[$node_index];
            my $in = $node->wild->{in};
            if ($in) { # not root


                my $parent_count;
                foreach my $edge_description (grep {!/coref|assoc|[\[\{\*\/]/} split /\|/,$in) { # avoid 'other' too?

                    if ($edge_description !~ /(.+?):(.+)/) {
                        log_warn "Unexpected value of 'in' attribute: $in";
                    }

                    else {
                        my ($offset,$afun) = ($1,$2);

                        if ($offset ==0) {
#                            log_warn "Offset shouldn't be zero: edge description: $in";
                        }
                        else {

                            $parent_count++;
                            if ($parent_count > 1) {
                                log_warn "there should not be more parents: $edge_description";
                            }

                            my $new_parent_index = $node_index+$offset;

                            if ($new_parent_index < 0 or $new_parent_index > $#nodes ) {
                                log_warn "parent index outside the array of nodes: $new_parent_index";
                            }

# this must be solved correctly, but there are wrong offsets in the data, probably shifted by one or two!!!!!!!!
#                            elsif ($node->wild->{para_number} != $nodes[$new_parent_index]->wild->{para_number}
#                                       or $node->wild->{sent_number} != $nodes[$new_parent_index]->wild->{sent_number}) {
#                                log_warn "edge leading to a different sentence or paragraph: $edge_description";
#                            }

                            else {

                                if (grep {$nodes[$new_parent_index] eq $_} $node->get_descendants) {
                                    log_warn "Not creating an edge that would lead to a cycle: form=" .
                                        $node->form . "  id=" . $node->id;
                                }
                                else {
                                    $node->set_parent($nodes[$new_parent_index]);
                                }

                                $node->set_conll_deprel($afun);
                                $node->set_tag($node->wild->{tag});
                                $node->set_lemma($node->wild->{lemma});
                            }
                        }
                    }
                }
            }
        }

        my $sentence = join ' ', grep { !/#[A-Z]/ } map { $_->form } $a_root->get_descendants( { ordered => 1 } );
        $zone->set_sentence($sentence);
    }

    return;
}

1;

=over

=item Treex::Block::Misc::CopenhagenDT::BuildTreesFromOffsetIndices

In CDT, node parent are identified by relative indices (offset in linear ordering).
This block assigns hangs nodes below their parents according to these indices.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

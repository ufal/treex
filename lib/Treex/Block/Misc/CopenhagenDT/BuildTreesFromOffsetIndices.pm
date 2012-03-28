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
        my %linenumber2node;
        foreach my $node (@nodes) {
            $linenumber2node{$node->wild->{linenumber}} = $node
                or log_fatal "Line number of a node in an original tag file not available";
        }

        foreach my $node ( @nodes ) {

            $node->set_tag($node->wild->{tag});
            $node->set_lemma($node->wild->{lemma});
            my $in_edges_description = $node->wild->{in};

            if ( defined $in_edges_description ) {
                foreach my $edge_description ( split /\|/,$in_edges_description) {
                    $self->_create_edge( $node, $edge_description, \%linenumber2node );
                }
            }
        }

        my $sentence = join ' ', grep { !/#[A-Z]/ }
            map { $_->form } $a_root->get_descendants( { ordered => 1 } );
        $zone->set_sentence( $sentence );

    }
    return;
}

sub _create_edge {
    my ( $self, $node, $edge_description, $linenumber2node_rf,  ) = @_;


    if ( $edge_description =~ /^[^1-9\-]/ ) { # this includes things like 'CONJ:add/(e)'
        # what should be done?
        return;
    }


    if ($edge_description !~ /(.+?):(.+)/) {
        log_warn "Unexpected value of 'in' attribute: $edge_description";
        return;
    }

    my ( $offset, $edge_label ) = ( $1, $2 );

    my $second_node = $linenumber2node_rf->{ $node->wild->{linenumber} + $offset };
    if (not defined $second_node) {
        log_warn "Problem0\tSecond node's index not available. No edge created for edge description: $edge_description";
        return;
    }

    elsif ( $edge_label =~ /SCENE|ref|rel|coref|cored|asso|[\[\{\*\/¹²³#]/ ) {
#        log_info "Non-tree edge: $edge_description";

    }

    else {
#        log_info "Tree edge: $edge_description";

        if ( $second_node eq $node ) {
            log_warn "Problem1\tCan't hang node below itself: $edge_description";
        }

        elsif (grep {$second_node eq $_} $node->get_descendants) {
            log_warn "Problem2\tCreating an edge that would lead to a dependency cycle: $edge_description form=" .
                $node->form . "  id=" . $node->id." . No edge created. Instead, the node is hanged below nearest left neighbor.";
            $self->_hang_below_substitute_parent($node,$linenumber2node_rf);
            $node->set_conll_deprel( $edge_label );
        }

        elsif ( $node->get_parent ne $node->get_root) {
            log_warn "Problem3\tNode would be hanged for the second time. No edge created. Edge description: $edge_description from ".$node->wild->{in};
        }

        else { # everything ok
            $node->set_parent( $second_node );
            $node->set_conll_deprel( $edge_label );
        }
    }
}

sub _hang_below_substitute_parent {
    my ( $self, $node, $linenumber2node_rf ) = @_;

    $node->wild->{ERROR} = 'substitute parent must have been used to avoid a cycle';

  NODE:
    foreach my $index (reverse ( 0 .. $node->wild->{linenumber} - 1 )) {

        my $substitute_parent = $linenumber2node_rf->{$index} or next NODE;

        if (defined $substitute_parent
                and not grep {$substitute_parent eq $_} $node->get_descendants) {
            $node->set_parent($substitute_parent);
            return;
        }
    }

    log_warn "Problem 6\tNo substitute parent found\n";
}


1;

=over

=item Treex::Block::Misc::CopenhagenDT::BuildTreesFromOffsetIndices

In CDT, node parent are identified by relative indices (offset in linear ordering
of lines in the original .tag files). This block assigns hangs nodes below
their parents according to these indices, and creates also other types of
(non-tree) edge, e.g. for coreference.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

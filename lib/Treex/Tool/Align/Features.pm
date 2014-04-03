package Treex::Tool::Align::Features;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Align::Utils;
use Graph;

with 'Treex::Tool::Align::FeaturesRole';

has '_sent_graphs' => ( is => 'rw', isa => 'HashRef[]', default => sub {{}});

my $NOT_GOLD_REGEX = '^(?!gold$)';

sub _unary_features {
    my ($self, $node, $type) = @_;

    my $feats = {};

    $feats->{id} = $node->id;

    return $feats;
}

sub _binary_features {
    my ($self, $set_features, $node1, $node2, $node2_ord) = @_;

    my $feats = {};

    _add_align_features($feats, $node1, $node2);

    return $feats;
}

sub _add_align_features {
    my ($feats, $node1, $node2) = @_;

    # all alignmnets excpt for the gold one projected from "ref"
    # TODO: do not project gold annotation to "src" => clearer solution
    my $nodes_aligned = Treex::Tool::Align::Utils::are_aligned($node1, $node2, { rel_types => [ $NOT_GOLD_REGEX ]});
    $feats->{giza_aligned} = $nodes_aligned ? 1 : 0;

    $self->_add_graph_features($feats, $node1, $node2);
}

sub _add_graph_features {
    my ($self, $feats, $node1, $node2) = @_;
    
    my $g = $self->_get_sent_graph($node1, $node2);
    
    my @node_path = $g->SP_Dijkstra($node1, $node2);

    $feats->{path_len} = @node_path - 1;
    $feats->{path_types} = _extract_path_types($g, @node_path);
}

sub _extract_path_types {
    my ($g, @nodes) = @_;
    my @type_seq = map {$g->get_edge_attribute($nodes[$_], $nodes[$_+1], "type")} 0 .. $#nodes-1;
    return join ",", @type_seq;
}

sub _get_sent_graph {
    my ($self, $l1_node, $l2_node) = @_;
    
    my $l1_ttree = $l1_node->get_root;
    my $l2_ttree = $l2_node->get_root;

    my $g = $self->_sent_graphs->{$l1_ttree->id};
    return $g if (defined $g);

    my @nodes = ($l1_ttree->get_descendants(), $l2_ttree->get_descendants());

    $g = Graph->new();
    foreach my $node (@nodes) {
        $g->set_edge_attribute($node, $node->get_parent, "type", "parent");
        $g->set_edge_attribute($node->get_parent, $node, "type", "child");
        my ($ali_nodes, $ali_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter($node, { directed => 1, rel_types => [ $NOT_GOLD_REGEX ]});
        foreach my $ali (@$ali_nodes) {
            $g->set_edge_attribute($node, $ali, "type", "align");
            $g->set_edge_attribute($ali, $node, "type", "align");
        }
    }
    $self->_sent_graphs->{$l1_ttree->id} = $g;
    $self->_sent_graphs->{$l2_ttree->id} = $g;

    return $g;
}


1;

package Treex::Tool::Align::Features;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Align::Utils;

with 'Treex::Tool::Align::FeaturesRole';

sub _unary_features {
    my ($self, $node, $type) = @_;

    return {};
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
    my $nodes_aligned = Treex::Tool::Align::Utils::are_aligned($node1, $node2, { rel_types => ['^(?!gold$)']});
    $feats->{giza_aligned} = $nodes_aligned ? 1 : 0;
}

1;

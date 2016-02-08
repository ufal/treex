package Treex::Block::Align::Annot::Print::A;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Align::Annot::Print::Base';
with 'Treex::Block::Filter::Node' => {
    layer => 'a',
};

sub _build_node_types {
    return 'all_anaph';
}

sub process_filtered_anode {
    my ($self, $anode) = @_;
    print "NODE_TYPES: " . Dumper($self->node_types);
    $self->_process_node($anode);
}

sub print_sentences {
    my ($self, $nodes, $langs, $zones) = @_;

    for (my $i = 0; $i < @$langs; $i++) {
        print {$self->_file_handle} uc($langs->[$i])."_A:\t" . _linearize_atree($zones->[$i], $nodes->{$langs->[$i]}) . "\n";
    }
}

sub _linearize_atree {
    my ($zone, $on_nodes) = @_;

    my %on_nodes_indic = map {$_->id => 1} @$on_nodes;

    my @tree_nodes = $zone->get_atree->get_descendants({ordered => 1});
    my @tree_forms = map {
        $on_nodes_indic{$_->id} ? "<" . $_->form . ">" : $_->form;
    } @tree_nodes;

    return join " ", @tree_forms;
}

1;

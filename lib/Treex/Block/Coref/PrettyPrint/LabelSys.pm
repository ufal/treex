package Treex::Block::Coref::PrettyPrint::LabelSys;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Core::Block';
with 'Treex::Block::Filter::Node';

sub _build_node_types {
    return 'all_anaph';
}

sub _build_layers {
    return "t";
}

sub process_filtered_tnode {
    my ($self, $tnode) = @_;
    
    $tnode->wild->{coref_diag}{is_anaph} = 1;
    $tnode->wild->{coref_diag}{cand_for}{$tnode->id} = 1;
    my @antes = $tnode->get_coref_nodes;
    foreach (@antes) { 
        $_->wild->{coref_diag}{sys_ante_for}{$tnode->id} = 1;
        $_->wild->{coref_diag}{cand_for}{$tnode->id} = 1;
    }
}

1;

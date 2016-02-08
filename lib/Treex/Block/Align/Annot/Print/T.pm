package Treex::Block::Align::Annot::Print::T;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Align::Annot::Print::Base';
with 'Treex::Block::Filter::Node' => {
    layer => 't',
};

sub _build_node_types {
    return 'all_anaph';
}

sub process_filtered_tnode {
    my ($self, $tnode) = @_;
    $self->_process_node($tnode);
}

sub print_sentences {
    my ($self, $nodes, $langs, $zones) = @_;

    for (my $i = 0; $i < @$langs; $i++) {
        print {$self->_file_handle} uc($langs->[$i]).":\t" . $zones->[$i]->sentence . "\n";
    }
    for (my $i = 0; $i < @$langs; $i++) {
        print {$self->_file_handle} uc($langs->[$i])."_T:\t" . _linearize_ttree_structured($zones->[$i], $nodes->{$langs->[$i]}) . "\n";
    }
}

sub _linearize_tnode {
    my ($tnode, $highlight_indic) = @_;
   
    my $word = "";
    
    my $anode = $tnode->get_lex_anode;
    if (defined $anode) {
        $word = $anode->form;
    }
    else {
        $word = $tnode->t_lemma .".". $tnode->functor;
    }
    $word =~ s/ /_/g;
    $word =~ s/</&lt;/g;
    $word =~ s/>/&gt;/g;
    $word =~ s/\[/&osb;/g;
    $word =~ s/\]/&csb;/g;

    if ($highlight_indic->{$tnode->id}) {
        $word = "<" . $word . ">";
    }
    my @hl_anodes = grep {$_->get_layer eq "a"} values %$highlight_indic;
    my ($hl_anode_idx) = grep {
        my ($hl_tnode) = $hl_anodes[$_]->get_referencing_nodes('a/aux.rf');
        defined $hl_tnode && $hl_tnode == $tnode
    } 0 .. $#hl_anodes;
    if (defined $hl_anode_idx) {
        $word = "<__A:". $hl_anodes[$hl_anode_idx]->id ."__". $word . ">";
    }
    return $word;
}

sub _linearize_ttree {
    my ($ttree, $highlight_arr) = @_;

    my $highlight_indic = { map {$_->id => $_} grep {defined $_} @$highlight_arr };

    my @words = map {_linearize_tnode($_, $highlight_indic)} $ttree->get_descendants({ordered => 1});
    return join " ", @words;
}

sub _linearize_ttree_structured {
    my ($ttree, $highlight_arr) = @_;
    
    my $highlight_indic = { map {$_->id => $_} grep {defined $_} @$highlight_arr };

    my ($sub_root) = $ttree->get_children({ordered => 1});
    my $str = _linearize_subtree_recur($sub_root, $highlight_indic);
    return $str;
}

sub _linearize_subtree_recur {
    my ($subtree, $highlight_indic) = @_;
    
    my $str = _linearize_tnode($subtree, $highlight_indic);
    my @childs = $subtree->get_children({ordered => 1});
    if (@childs) {
        $str .= " [ ";
        my @child_strs = map {_linearize_subtree_recur($_, $highlight_indic)} @childs;
        $str .= join " ", @child_strs;
        $str .= " ]";
    }
    return $str;
}

1;

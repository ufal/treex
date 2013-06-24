use Treex::Core; # -*- cperl -*-
#use Treex::Core::TredView::BackendStorable;


# the following line is used to avoid memory leaks caused
# by keeping history for undo in tred (only with treex files);
# ideally it should be done only when switching to this mode,
# and reverted when exiting it
$TrEd::Config::maxUndo = 0;

use strict;
our ($grp, $root);

use Treex::Core::TredView;
my $tredview = Treex::Core::TredView->new({grp=>$grp});

sub is_treex_doc {
    if (defined $grp
            and defined $grp->{FSFile}
                and defined $grp->{FSFile}->metaData('schema')
                    and $grp->{FSFile}->metaData('schema')->get_root_name() eq 'treex_document') {
        return 1;
    }
    return 0;
}

push @TredMacro::AUTO_CONTEXT_GUESSING, sub {
    my ($hook)=@_;
    my $resuming = ($hook eq 'file_resumed_hook');

    if (is_treex_doc()) {
        SetCurrentStylesheet(STYLESHEET_FROM_FILE()) if $resuming;
        return 'Treex_mode';
    }
    return;
};

sub allow_switch_context_hook {
    return 'stop' unless is_treex_doc();
}

sub switch_context_hook {
    my $cur_stylesheet = GetCurrentStylesheet();
    if ($cur_stylesheet ne 'Treex_stylesheet') {
        $tredview->tree_layout->load_layouts();
        SetCurrentStylesheet('Treex_stylesheet');
        Redraw() if GUI();
    }
}

sub pre_switch_context_hook {
    $tredview->tree_layout->save_layouts();
}

sub pre_switch_stylesheet_hook {
    return 'stop' if $_[1] eq STYLESHEET_FROM_FILE();
}

sub file_opened_hook {
    $tredview->file_opened_hook(@_);
}

sub file_reloaded_hook {
    file_opened_hook();
}

sub get_nodelist_hook {
    return $tredview->get_nodelist_hook(@_);
}

sub get_value_line_hook {
    return $tredview->get_value_line_hook(@_);
}

sub value_line_doubleclick_hook {
    return $tredview->value_line_doubleclick_hook(@_);
}

sub node_style_hook {
    return $tredview->node_style_hook(@_);
}

sub root_style_hook {
    return $tredview->root_style_hook(@_);
}

sub ConfDialog {
    $tredview->conf_dialog();
}

sub init_hook {
    $tredview->tree_layout->load_layouts();
}

sub exit_hook {
    $tredview->tree_layout->save_layouts();
}

sub shift_labels1_layer {
    $tredview->labels->shift_labels(0, 'layer');
}

sub shift_labels1_node {
    $tredview->labels->shift_labels(0, 'node');
}

sub shift_labels2_layer {
    $tredview->labels->shift_labels(1, 'layer');
}

sub shift_labels2_node {
    $tredview->labels->shift_labels(1, 'node');
}

sub shift_labels3_layer {
    $tredview->labels->shift_labels(2, 'layer');
}

sub shift_labels3_node {
    $tredview->labels->shift_labels(2, 'node');
}

sub reset_labels_node {
    $tredview->labels->reset_labels('node');
}

sub reset_labels_tree {
    $tredview->labels->reset_labels('tree');
}

sub toggle_clause_collapsing {
    $tredview->toggle_clause_collapsing($root);
}

sub toggle_alignment {
    $tredview->toggle_alignment();
}

sub toggle_tree_wrapping {
    $tredview->toggle_tree_wrapping($this);
}

sub OpenValLexicon {
    $tredview->vallex->OpenValLexicon();
}

sub ChooseValFrame {
    $tredview->vallex->ChooseValFrame();
}

sub recompute_visualization {
    $tredview->recompute_visualization($root);
}

sub after_edit_attr_hook {
    $tredview->recompute_visualization($root);
}

sub after_edit_node_hook {
    $tredview->recompute_visualization($root);
}

sub node_release_hook {
    return $tredview->node_release_hook(@_);
}

sub node_click_hook {
    return $tredview->node_click_hook(@_);
}


my $command;

sub annotation_command {

    if (defined $command) {
        ($command) = split ' ',$command;
        $command .= ' ';
    }

    $command=QueryString("Enter annotation command:","command",$command);
    if (defined($command)) {
        $tredview->run_annotation_command($command,$this);
    }
}

#bind annotation_command to space
#bind recompute_visualization to q
#bind ConfDialog to c menu Configuration
#bind shift_labels1_layer to 1 menu Change content of label no.1 for current layer
#bind shift_labels1_node to Ctrl+1 menu Change content of label no.1 for current node
#bind shift_labels2_layer to 2 menu Change content of label no.2 for current layer
#bind shift_labels2_node to Ctrl+2 menu Change content of label no.2 for current node
#bind shift_labels3_layer to 3 menu Change content of label no.3 for current layer
#bind shift_labels3_node to Ctrl+3 menu Change content of label no.3 for current node
#bind shift_labels1_layer to KP_End
#bind shift_labels1_node to Ctrl+KP_End
#bind shift_labels2_layer to KP_Down
#bind shift_labels2_node to Ctrl+KP_Down
#bind shift_labels3_layer to KP_Next
#bind shift_labels3_node to Ctrl+KP_Next
#bind reset_labels_node to r menu Reset label settings of current node
#bind reset_labels_tree to Ctrl+r menu Reset label settings of all nodes in current tree
#bind toggle_clause_collapsing to l
#bind toggle_alignment to a menu Toggle alignment arrows
#bind toggle_tree_wrapping to w menu Wrap tree

#bind OpenValLexicon to Ctrl+Shift+Return menu Browse valency frame lexicon
#bind ChooseValFrame to Ctrl+Return menu Select and assign valency frame

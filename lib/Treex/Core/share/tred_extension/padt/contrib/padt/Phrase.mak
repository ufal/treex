# ########################################################################## Otakar Smrz, 2005/07/13
#
# PADT Phrase Context for the TrEd Environment #####################################################

# $Id: Phrase.mak 4948 2012-10-16 22:12:17Z smrz $

package PADT::Phrase;

use 5.008;

use strict;

our $VERSION = do { q $Revision: 4948 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };

# ##################################################################################################
#
# ##################################################################################################

#binding-context PADT::Phrase

BEGIN {

    import PADT 'switch_context_hook', 'pre_switch_context_hook', 'idx';

    import TredMacro;
}

our ($this, $root, $grp);

our ($Redraw);

our ($option, $fill) = ({}, ' ' x 4);

# ##################################################################################################
#
# ##################################################################################################

sub CreateStylesheets {

    return << '>>';

rootstyle:<? '#{vertical}#{Node-textalign:left}' ?>

style:<? '#{Line-coords:n,n,p,n,p,p}' ?>

node:<? $this->{morph} eq '' ? '#{custom1}${label}' : '#{custom6}${form}' ?>

node:#{custom4}${tag_2}

node:#{custom5}${tag_3}

node:#{custom2}${morph}

node:#{custom3}${tag_1}

hint:<? join "\n", 'morph: ${morph}',
                   'label: ${label}'
                   'tag_1: ${tag_1}'
                   'tag_2: ${tag_2}'
                   'tag_3: ${tag_3}'
                   'comment: ${comment}' ?>
>>
}

#bind tree_justify_mode Ctrl+j menu Toggle Tree Justify Mode
sub tree_justify_mode {

    $$option->{$grp}{'just'} = not $option->{$grp}{'just'};

    ChangingFile(0);
}

sub get_nodelist_hook {

    my ($fsfile, $index, $recent, $show_hidden) = @_;
    my ($nodes, $current);

    my $tree = $fsfile->tree($index);

    ($nodes, $current) = $fsfile->nodes($index, $recent, $show_hidden);

    @{$nodes} = sort { $a->{'ord_just'} <=> $b->{'ord_just'} } @{$nodes} if $option->{$grp}{'just'};

    @{$nodes} = reverse @{$nodes} if $main::treeViewOpts->{reverseNodeOrder};

    return [$nodes, $current];
}

sub get_value_line_hook {

    my ($fsfile, $index) = @_;
    my ($nodes, $words, $views);

    ($nodes, undef) = $fsfile->nodes($index, $this, 1);

    $views->{$_->{'ord'}} = $_ foreach GetVisibleNodes($root);

    if ($main::treeViewOpts->{reverseNodeOrder}) {

        $words = [ [ '#' . ($index + 1), $nodes->[0], '-foreground => darkmagenta'],
                   [ " " ],

                   map {

                       show_value_line_node($views, $_, 'origf', $_->{'tag_2'} eq '-' x 10)

                   } @{$nodes} ];

        @{$words} = reverse @{$words};
    }
    else {

        $words = [ [ '#' . ($index + 1), $nodes->[0], '-foreground => darkmagenta'],
                   [ " " ],

                   map {

                       show_value_line_node($views, $_, 'morph', $_->{'tag_1'} eq '-NONE-')

                   } @{$nodes} ];
    }

    return $words;
}

sub show_value_line_node {

    my ($view, $node, $text, $warn) = @_;

    if (HiddenVisible()) {

        return  unless defined $node->{'origf'} and $node->{'origf'} ne '';

        return  [ $node->{$text}, $node, exists $view->{$node->{'ord'}} ? $warn ? '-foreground => red' : ()
                                                                                : '-foreground => gray' ],
                [ " " ];
    }
    else {

        return  [ '.....', $view->{$node->{'ord'} - 1}, '-foreground => magenta' ],
                [ " " ]
                        if not exists $view->{$node->{'ord'}} and exists $view->{$node->{'ord'} - 1};

        return  unless exists $view->{$node->{'ord'}} and defined $node->{'origf'} and $node->{'origf'} ne '';

        return  [ $node->{$text}, $node, $warn ? '-foreground => red' : () ],
                [ " " ];
    }
}

sub highlight_value_line_tag_hook {

    my $node = $grp->{currentNode};

    $node = PrevNodeLinear($node, 'ord') until !$node or defined $node->{'origf'} and $node->{'origf'} ne '';

    return $node;
}

sub node_release_hook {

    my ($node, $done) = @_;
    my (@line);

    return unless $done;

    return unless $option->{$grp}{'hook'};

    while ($done->{'afun'} eq '???' and $done->{'afunaux'} eq '') {

        unshift @line, $done;

        $done = $done->parent();
    }

    request_auto_afun_node($_) foreach @line, $node;
}

sub node_moved_hook {

    return unless $option->{$grp}{'hook'};

    my (undef, $done) = @_;

    my @line;

    while ($done->{'afun'} eq '???' and $done->{'afunaux'} eq '') {

        unshift @line, $done;

        $done = $done->parent();
    }

    request_auto_afun_node($_) foreach @line;
}

sub root_style_hook {

}

sub node_style_hook {

}

# ##################################################################################################
#
# ##################################################################################################

sub referring_Ref {

    return undef;
}

sub referring_Msd {

    return undef;
}

# ##################################################################################################
#
# ##################################################################################################

sub enable_attr_hook {

    return 'stop' unless $_[0] =~ /^(?:afun|parallel|paren|arabclause|arabfa|arabspec|comment|err1|err2)$/;
}

#bind edit_comment to exclam menu Annotate: Edit annotator's comment
sub edit_comment {

    $Redraw = 'none';
    ChangingFile(0);

    my $comment = $grp->{FSFile}->FS->exists('comment') ? 'comment' : undef;

    unless (defined $comment) {

        ToplevelFrame()->messageBox (
            -icon => 'warning',
            -message => "No attribute for annotator's comment in this file",
            -title => 'Sorry',
            -type => 'OK',
        );

        return;
    }

    my $value = $this->{$comment};

    $value = main::QueryString($grp->{framegroup}, "Enter comment", $comment, $value);

    if (defined $value) {

        $this->{$comment} = $value;

        $Redraw = 'tree';
        ChangingFile(1);
    }
}

#bind toggle_tag_1 to Ctrl+F1 menu Show / Hide Morphological Tags 1
sub toggle_tag_1 {

    toggle_tags('node:', '#{custom3}${tag_1}');

    ChangingFile(0);
}

#bind toggle_tag_2 to Ctrl+F2 menu Show / Hide Morphological Tags 2
sub toggle_tag_2 {

    toggle_tags('node:', '#{custom4}${tag_2}');

    ChangingFile(0);
}

#bind toggle_tag_3 to Ctrl+F3 menu Show / Hide Morphological Tags 3
sub toggle_tag_3 {

    toggle_tags('node:', '#{custom5}${tag_3}');

    ChangingFile(0);
}

sub toggle_tags {

    return unless $grp->{FSFile};

    my ($type, $pattern) = @_;

    my ($hint, $cntxt, $style) = GetStylesheetPatterns();

    my @filter = grep { $_ !~ /^(?:\Q${type}\E\s*)?\Q${pattern}\E$/ } @{$style};

    SetStylesheetPatterns([ $hint, $cntxt, [ @filter, @{$style} == @filter ? $type . ' ' . $pattern : () ] ]);

    ChangingFile(0);
}

#bind invoke_undo BackSpace menu Annotate: Undo recent annotation action
sub invoke_undo {

    warn 'Undoooooing ;)';

    main::undo($grp);
    $this = $grp->{currentNode};

    ChangingFile(0);
}

#bind direction_RTL to Ctrl+r menu Display Trees Right-to-Left
sub direction_RTL {

    TredMacro::initialize_direction('right-to-left', 'right');

    Redraw_All();
    ChangingFile(0);
}

#bind direction_LTR to Ctrl+l menu Display Trees Left-to-Right
sub direction_LTR {

    TredMacro::initialize_direction('left-to-right', 'left');

    Redraw_All();
    ChangingFile(0);
}

# ##################################################################################################
#
# ##################################################################################################

use List::Util 'reduce';

#bind move_word_home Home menu Move to First Word
sub move_word_home {

    $this = reduce { $a->{'ord'} < $b->{'ord'} ? $a : $b } GetVisibleNodes($root);

    $Redraw = 'none';
    ChangingFile(0);
}

#bind move_word_end End menu Move to Last Word
sub move_word_end {

    $this = reduce { $a->{'ord'} > $b->{'ord'} ? $a : $b } GetVisibleNodes($root);

    $Redraw = 'none';
    ChangingFile(0);
}

OverrideBuiltinBinding(__PACKAGE__, "Shift+Home", [ MacroCallback('move_deep_home'), 'Move to Rightmost Descendant' ]);

#bind move_deep_home Shift+Home menu Move to Rightmost Descendant
sub move_deep_home {

    $this = $this->leftmost_descendant();

    $this = PrevVisibleNode($this) if IsHidden($this);

    $Redraw = 'none';
    ChangingFile(0);
}

OverrideBuiltinBinding(__PACKAGE__, "Shift+End", [ MacroCallback('move_deep_end'), 'Move to Leftmost Descendant' ]);

#bind move_deep_end Shift+End menu Move to Leftmost Descendant
sub move_deep_end {

    $this = $this->rightmost_descendant();

    $this = NextVisibleNode($this) || PrevVisibleNode($this) if IsHidden($this);

    $Redraw = 'none';
    ChangingFile(0);
}

#bind move_par_home Ctrl+Home menu Move to First Paragraph
sub move_par_home {

    GotoTree(1);

    $Redraw = 'win';
    ChangingFile(0);
}

#bind move_par_end Ctrl+End menu Move to Last Paragraph
sub move_par_end {

    GotoTree($grp->{FSFile}->lastTreeNo + 1);

    $Redraw = 'win';
    ChangingFile(0);
}

#bind move_to_next_paragraph Shift+Next menu Move to Next Paragraph
sub move_to_next_paragraph {

    NextTree();

    $Redraw = 'win';
    ChangingFile(0);
}

#bind move_to_prev_paragraph Shift+Prior menu Move to Prev Paragraph
sub move_to_prev_paragraph {

    PrevTree();

    $Redraw = 'win';
    ChangingFile(0);
}

#bind tree_hide_mode Ctrl+equal menu Toggle Children Hiding
sub tree_hide_mode {

    foreach my $node ($this->children()) {

        $node->{'hide'} = $node->{'hide'} ? '' : 'hide';
    }

    ChangingFile(0);
}

#bind unhide_subtree Ctrl+plus menu Unhide Children Recursively
sub unhide_subtree {

    my $this = ref $_[0] ? $_[0] : $this;

    $this->{'hide'} = '';

    foreach my $node ($this->children()) {

        unhide_subtree($node);
    }

    ChangingFile(0);
}

#bind hide_children Ctrl+minus menu Hide Children Subtrees
sub hide_children {

    foreach my $node ($this->children()) {

        $node->{'hide'} = 'hide';
    }

    ChangingFile(0);
}

#bind hide_this Ctrl+underscore menu Hide This Subtree
sub hide_this {

    $this->{'hide'} = $this->{'hide'} ? '' : 'hide';

    ChangingFile(0);
}

#bind move_to_root Ctrl+Shift+Up menu Move Up to Root
sub move_to_root {

    $this = $root unless $root == $this;

    $Redraw = 'none';
    ChangingFile(0);
}

#bind move_to_fork Ctrl+Shift+Down menu Move Down to Fork
sub move_to_fork {

    my $node = $this;
    my (@children);

    while (@children = $node->children()) {

        @children = grep { $_->{'hide'} ne 'hide' } @children;

        last unless @children == 1;

        $node = $children[0];
    }

    $this = $node unless $node == $this;

    $Redraw = 'none';
    ChangingFile(0);
}

#bind ThisAddressClipBoard Ctrl+Return menu ThisAddress() to Clipboard
sub ThisAddressClipBoard {

    my $reply = main::userQuery($grp,
                        "\nCopy this node's address to clipboard?\t",
                        -bitmap=> 'question',
                        -title => "Clipboard",
                        -buttons => ['Yes', 'No']);

    return unless $reply eq 'Yes';

    my $widget = ToplevelFrame();

    $widget->clipboardClear();
    $widget->clipboardAppend(ThisAddress());

    $Redraw = 'none';
    ChangingFile(0);
}

# ##################################################################################################
#
# ##################################################################################################

no strict;

1;


=head1 NAME

PADT::Phrase - Context for Annotation of Constituency Syntax in the TrEd Environment


=head1 DESCRIPTION

Prague Arabic Dependency Treebank L<http://ufal.mff.cuni.cz/padt/online/>

TrEd Tree Editor L<http://ufal.mff.cuni.cz/tred/>


=head1 AUTHOR

Otakar Smrz E<lt>otakar.smrz seznam.czE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2005-2011 by Otakar Smrz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

# ########################################################################## Otakar Smrz, 2009/08/12
#
# PADT Words Context for the TrEd Environment ######################################################

# $Id: Words.mak 4948 2012-10-16 22:12:17Z smrz $

package PADT::Words;

use 5.008;

use strict;

use File::Spec;
use File::Copy;

use File::Basename;

our $VERSION = join '.', '1.1', q $Revision: 4948 $ =~ /(\d+)/;

# ##################################################################################################
#
# ##################################################################################################

#binding-context PADT::Words

BEGIN {

    import PADT 'switch_context_hook', 'pre_switch_context_hook', 'idx';

    import TredMacro;
}

our ($this, $root, $grp);

our ($Redraw);

our ($dims, $fill) = (10, ' ' x 4);

sub words {

    my $text = $_[0];

    my @words = $text =~ /(?: \G \P{IsGraph}* ( (?: \p{Arabic} | [\x{064B}-\x{0652}\x{0670}\x{0657}\x{0656}\x{0640}] |
                                                 # \p{InArabic} |   # too general
                                                \p{InArabicPresentationFormsA} | \p{InArabicPresentationFormsB} )+ |
                                                \p{Latin}+ |
                                                $PADT::regexQ |
                                                $PADT::regexG |
                                                \p{IsGraph} ) )/ogx;

    return @words;
}

# ##################################################################################################
#
# ##################################################################################################

#bind update_words Ctrl+w menu Update Words
sub update_words {

    my $level = $this->level();

    my $node;

    if ($level == 0) {

        create_words($_) foreach $this->children();
    }
    else {

        $this = $this->parent() foreach 1 .. $level - 1;

        create_words($this);
    }
}

sub create_words {

    my $unit = $_[0];

    DeleteSubtree($_) foreach $unit->children();

    my @words = words $unit->{'form'};

    for (my $i = @words; $i > 0; $i--) {

        my $node = NewSon($unit);

        DetermineNodeType($node);

        $node->{'form'} = $words[$i - 1];

        $node->{'id'} = $unit->{'id'} . 'w' . $i;
    }
}

#bind delete_subtree Ctrl+d menu Edit: Delete Subtree
sub delete_subtree {

    my $node = $this->rbrother() || $this->lbrother() || $this->parent();

    DeleteSubtree($this);

    $this = $node;
}

#bind cut_subtree Ctrl+x menu Edit: Cut Subtree
sub cut_subtree {

    TredMacro::CutToClipboard($this);
}

#bind paste_subtree Ctrl+v menu Edit: Paste Subtree
sub paste_subtree {

    ChangingFile(0);

    return unless defined $TredMacro::nodeClipboard;

    if (not $this->test_child_type($TredMacro::nodeClipboard) and
        $this->parent() and
        $this->parent()->test_child_type($TredMacro::nodeClipboard)) {

        PasteNodeAfter($TredMacro::nodeClipboard, $this);

        $this = $TredMacro::nodeClipboard;

        $TredMacro::nodeClipboard = undef;
    }
    else {

        TredMacro::PasteFromClipboard();
    }

    ChangingFile(1);
}

#bind copy_subtree Ctrl+c menu Edit: Copy Subtree
sub copy_subtree {

    $TredMacro::nodeClipboard = CloneSubtree($this);
}

# ##################################################################################################
#
# ##################################################################################################

sub CreateStylesheets {

    return << '>>';

style:<? exists $this->{'note'} && $this->{'note'} ne '' ? '#{Line-fill:red}' : '' ?>

node:<? exists $this->{'note'} && $this->{'note'} ne '' ? '#{custom2}' . $this->{'form'} : $this->{'form'} ?>

node:<? exists $this->{'note'} && $this->{'note'} ne '' ? '#{custom3}' . $this->{'note'} : '' ?>
>>
}

sub node_release_hook {

    my ($node, $done, $mode) = @_;

    return unless $done;

    my $diff = $node->level() - $done->level();

    if ($diff == 1) {

        return;
    }
    else {

        if ($diff == 0) {

            shuffle_node($node, $done);

            Redraw_FSFile_Tree();
            main::centerTo($grp, $grp->{currentNode});
            ChangingFile(1);
        }

        return 'stop';
    }
}

sub shuffle_node ($$) {

    my ($node, $done) = @_;

    my ($fore) = grep { $_ == $node or $_ == $done } GetNodes();

    if ($node == $fore) {

        CutPasteAfter($node, $done);
    }
    else {

        CutPasteBefore($node, $done);
    }
}

sub get_nodelist_hook {

    my ($fsfile, $index, $recent, $show_hidden) = @_;
    my ($nodes, $current);

    ($nodes, $current) = $fsfile->nodes($index, $recent, $show_hidden);

    @{$nodes} = reverse @{$nodes} if $main::treeViewOpts->{reverseNodeOrder};

    return [$nodes, $current];
}

sub get_value_line_hook {

    my ($fsfile, $index) = @_;
    my ($nodes, $words, $views);

    ($nodes, undef) = $fsfile->nodes($index, $this, 1);

    $words = [ [ $nodes->[0]->{'form'} . " " . idx($nodes->[0]), $nodes->[0], '-foreground => darkmagenta' ],

               [ " " ],

               map {

                    $_->parent() == $root ? [ '.....', $_, '-foreground => magenta' ]

                                          : [ $_->{'form'}, $_, $_->parent() ],

                    [ " ", defined $_->following($_->parent()) ? $_->parent() : () ],

               } grep { not $_->children() } @{$nodes}[1 .. $#{$nodes}] ];

    @{$words} = reverse @{$words} if $main::treeViewOpts->{reverseNodeOrder};

    return $words;
}

sub highlight_value_line_tag_hook {

    return $grp->{currentNode};
}

sub value_line_doubleclick_hook {

}

sub node_doubleclick_hook {

    return 'stop';
}

sub node_click_hook {

    return 'stop';
}

#bind move_word_home Home menu Move to First Nest
sub move_word_home {

    $this = ($root->children())[0];

    $Redraw = 'none';
    ChangingFile(0);
}

#bind move_word_end End menu Move to Last Nest
sub move_word_end {

    $this = ($root->children())[-1];

    $Redraw = 'none';
    ChangingFile(0);
}

OverrideBuiltinBinding(__PACKAGE__, "Shift+Home", [ MacroCallback('move_next_home'), 'Move to First on Level' ]);

#bind move_next_home Shift+Home menu Move to First on Level
sub move_next_home {

    my $node = $this;
    my $level = $node->level();

    my $done;
    my $roof = $level > 1 ? $this->parent() : $this;

    my @children = grep { not IsHidden($_) } $this->children();

    do {

        $done = $node if $level == $node->level();

        $node = PrevVisibleNode($node, $roof);
    }
    while $node and not $node == $roof;     # unexpected extra check ...

    if ($done == $this and @children) {

        $this = $children[0];
    }
    else {

        $this = $done;
    }

    $Redraw = 'none';
    ChangingFile(0);
}

OverrideBuiltinBinding(__PACKAGE__, "Shift+End", [ MacroCallback('move_next_end'), 'Move to Last on Level' ]);

#bind move_next_end Shift+End menu Move to Last on Level
sub move_next_end {

    my $node = $this;
    my $level = $node->level();

    my $done;
    my $roof = $level > 1 ? $this->parent() : $this;

    my @children = grep { not IsHidden($_) } $this->children();

    do {

        $done = $node if $level == $node->level();

        $node = NextVisibleNode($node, $roof);
    }
    while $node;

    if ($done == $this and @children) {

        $this = $children[-1];
    }
    else {

        $this = $done;
    }

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

#bind invoke_undo BackSpace menu Undo Action
sub invoke_undo {

    warn 'Undoooooing ;)';

    main::undo($grp);
    $this = $grp->{currentNode};

    ChangingFile(0);
}

#bind invoke_redo Shift+BackSpace menu Redo Action
sub invoke_redo {

    warn 'Redoooooing ;)';

    main::re_do($grp);
    $this = $grp->{currentNode};

    ChangingFile(0);
}

# ##################################################################################################
#
# ##################################################################################################

sub path (@) {

    return File::Spec->join(@_);
}

sub escape ($) {

    return $^O eq 'MSWin32' ? '"' . $_[0] . '"' : "'" . $_[0] . "'";
}

sub espace ($) {

    my $name = $_[0];

    $name =~ s/\\/\//g if $^O eq 'MSWin32' and $name =~ / /;

    return escape $name;
}

sub inter_with_level ($) {

    my ($inter, $level) = ('words', $_[0]);

    my (@file, $path, $name, $exts);

    my $file = File::Spec->canonpath(FileName());

    ($name, $path, $exts) = fileparse($file, '.exclude.pml', '.pml');

    ($name, undef, undef) = fileparse($name, ".$inter");

    $file[0] = path $path, $name . ".$inter" . $exts;

    $file[1] = $level eq 'elixir' ? ( path $path, $name . ".$level" . (substr $exts, 0, -3) . "dat" )
                                  : ( path $path, $name . ".$level" . $exts );

    unless ($file[0] eq $file) {

        ToplevelFrame()->messageBox (
            -icon => 'warning',
            -message => "This file's name does not fit the directory structure!$fill\n" .
                        "Relocate it to " . $name . ".$inter" . $exts . ".$fill",
            -title => 'Error',
            -type => 'OK',
        );

        return;
    }

    return $level, $name, $path, @file;
}

#bind open_level_words_prime to Alt+0
sub open_level_words_prime {

    open_level_words();
}

#bind open_level_morpho_prime to Alt+1
sub open_level_morpho_prime {

    open_level_morpho();
}

#bind open_level_syntax_prime to Alt+2
sub open_level_syntax_prime {

    open_level_syntax();
}

#bind open_level_tecto_prime to Alt+3
sub open_level_tecto_prime {

    open_level_tecto();
}

#bind open_level_words to Ctrl+Alt+0 menu Action: Edit Analytic File
sub open_level_words {

    ChangingFile(0);
}

#bind open_level_morpho to Ctrl+Alt+1 menu Action: Edit MorphoTrees File
sub open_level_morpho {

    ChangingFile(0);

    my ($level, $name, $path, @file) = inter_with_level 'morpho';

    return unless defined $level;

    unless (-f $file[1]) {

        my $reply = main::userQuery($grp,
                        "\nThere is no " . $name . ".$level.pml" . " file.$fill" .
                        "\nReally create a new one?$fill",
                        -bitmap=> 'question',
                        -title => "Creating",
                        -buttons => ['Yes', 'No']);

        return unless $reply eq 'Yes';

        if (-f $file[2]) {

            ToplevelFrame()->messageBox (
                -icon => 'warning',
                -message => "Cannot create " . ( path '..', "$level", $name . ".$level.pml" ) . "!$fill\n" .
                            "Please remove " . ( path '..', 'morpho', $name . ".$level.pml" ) . ".$fill",
                -title => 'Error',
                -type => 'OK',
            );

            return;
        }

        if (GetFileSaveStatus()) {

            ToplevelFrame()->messageBox (
                -icon => 'warning',
                -message => "The current file has been modified. Either save it, or reload it discarding the changes.$fill",
                -title => 'Error',
                -type => 'OK',
            );

            return;
        }

        system 'btred -QI ' . ( escape CallerDir('../../exec/words_morpho.ntred') ) .
                        ' ' . ( espace $file[0] );

        move $file[2], $file[1];
    }

    my $rf = 'w#' . $this->{'id'};

    if (Open($file[1])) {

        my $idx = CurrentTreeNumber();

        GotoTree(1);

        {
            do {

                do {

                    last if exists $this->{'w.rf'} and $this->{'w.rf'} eq $rf;
                }
                while $this = $this->following();
            }
            while NextTree();
        }

        unless (exists $this->{'w.rf'} and $this->{'w.rf'} eq $rf) {

            GotoTree($idx + 1);

            $this = $root;
        }
    }
    else {

        SwitchContext('PADT::Words');
    }
}

#bind open_level_syntax to Ctrl+Alt+2 menu Action: Edit Analytic File
sub open_level_syntax {

    ChangingFile(0);

    my ($level, $name, $path, @file) = inter_with_level 'syntax';

    return unless defined $level;

    my @id = idx($root);

    my $id = join 's-', split 'w-', $this->{'id'};

    if (Open($file[1])) {

        GotoTree($id[0]);

        $this = PML::GetNodeByID($id) ||
                PML::GetNodeByID($id . 't1') ||
                PML::GetNodeByID($id . 'l1t1') || $root;
    }
    else {

        SwitchContext('PADT::Words');
    }
}

#bind open_level_tecto to Ctrl+Alt+3 menu Action: Edit DeepLevels File
sub open_level_tecto {

    ChangingFile(0);

    my ($level, $name, $path, @file) = inter_with_level 'deeper';

    return unless defined $level;

    my @id = idx($root);

    my $id = join 'd-', split 'w-', $this->{'id'};

    if (Open($file[1])) {

        GotoTree($id[0]);

        $this = PML::GetNodeByID($id) ||
                PML::GetNodeByID($id . 't1') ||
                PML::GetNodeByID($id . 'l1t1') || $root;
    }
    else {

        SwitchContext('PADT::Words');
    }
}

#bind ThisAddressClipBoard Ctrl+Return menu ThisAddress() to Clipboard
sub ThisAddressClipBoard {

    my $reply = main::userQuery($grp,
                        "\nCopy this node's address to clipboard?$fill",
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

PADT::Words - Context for Accessing the Words Level in the TrEd Environment


=head1 DESCRIPTION

Prague Arabic Dependency Treebank L<http://ufal.mff.cuni.cz/padt/online/>

TrEd Tree Editor L<http://ufal.mff.cuni.cz/tred/>


=head1 AUTHOR

Otakar Smrz E<lt>otakar.smrz seznam.czE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2006-2011 by Otakar Smrz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

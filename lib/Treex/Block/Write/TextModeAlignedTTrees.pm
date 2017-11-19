package Treex::Block::Write::TextModeAlignedTTrees;
use Moose;
use Treex::Core::Common;
use Term::ANSIColor qw(colored colorstrip);
extends 'Treex::Block::Write::BaseTextWriter';

use Data::Printer;

has print_sent_id => ( is=>'ro', isa=>'Bool', default=>0 );
has print_sentence => ( is=>'ro', isa=>'Bool', default=>0 );
has add_empty_line => ( is=>'rw', isa=>'Bool', default=>1 );
has indent   => ( is=>'ro', isa => 'Int',  default => 1, documentation => 'number of columns for better readability');
has minimize_cross => ( is=>'ro', isa => 'Bool', default => 1, documentation => 'minimize crossings of edges in non-projective trees');
has color      => ( is=>'rw', isa=>'Bool', default=> 1 );
has attributes => ( is=>'ro', default=>'ord,t_lemma,gram/sempos,functor,id' );
has print_undef_as => (is=>'ro', default=>'');
has colspace => ( is => 'ro', isa => "Int", default => 5 );
has zones => ( is => 'ro', isa => 'Str', required => 1 );

my %COLOR_OF = (
    t_lemma => 'cyan',
    functor => 'bright_blue',
    'gram/sempos' => 'bright_red',
    ord => 'bright_yellow',
);

# Symbols for drawing edges
my (@DRAW, @SPACE, $H, $V);
my @ATTRS;

sub BUILD {
    my ($self) = @_;

    # $DRAW[bottom-most][top-most]
    my $line = '─' x $self->indent;
    $H          = $line . '─';
    $DRAW[1][1] = $H;
    $DRAW[1][0] = $line . '┘';
    $DRAW[0][1] = $line . '┐';
    $DRAW[0][0] = $line . '┤';

    # $SPACE[bottom-most][top-most]
    my $space = ' ' x $self->indent;
    $SPACE[1][0] = $space . '└';
    $SPACE[0][1] = $space . '┌';
    $SPACE[0][0] = $space . '├';
    $V           = $space . '│';

    @ATTRS = split /,/, $self->attributes;
    return;
}

# We want to be able to call process_tree not only on root node,
# so this block can be called from $node->print_subtree($args)
# on any node and print its subtree. Thus, we cannot assume that
# $all[$idx]->ord == $idx. Instead of $node->ord, we'll use $index_of{$node},
# which is its index within the printed subtree.
# $gaps{$node} = number of nodes within $node's span, which are not its descendants.
sub _compute_gaps {
    my ($node, $gaps, $index_of) = @_;
    my ($lmost, $rmost, $descs) = ($index_of->{$node}, $index_of->{$node}, 0);
    foreach my $child ($node->get_children()){
        my ($lm, $rm, $de) =_compute_gaps($child, $gaps, $index_of);
        $lmost = min($lm, $lmost);
        $rmost = max($rm, $rmost);
        $descs += $de;
    }
    $gaps->{$node} = $rmost - $lmost - $descs;
    return($lmost, $rmost, $descs + 1);
}

sub _length {
    my ($self, $str) = @_;
    return length colorstrip($str);
}

sub _add_padding {
   my ($self, $lines) = @_;
   my $max_length = max map {$self->_length($_)} @$lines;
   my @padded_lines = map {
        my $add_pad = $max_length - $self->_length($_);
        $_ . (' 'x$add_pad)
   } @$lines;
   return @padded_lines;
}

sub align_to_lines {
    my ($self, $tree, $lang, $sel) = @_;
    # add an empty line at the beginning to increase readibility
    my @lines = ("");
    foreach my $node ($tree->get_descendants({ordered => 1})) {
        my ($alin, $alit) = $node->get_undirected_aligned_nodes({language => $lang, selector => $sel});
        my @alistrs = map {sprintf "(%d, %d, %s)", $node->ord, $alin->[$_]->ord, $alit->[$_]} 0..$#$alin;
        push @lines, @alistrs;
    }
    return @lines;
}

sub process_bundle {
    my ($self, $bundle) = @_;

    my @all_trees = ();
    my $prev_tree = undef;
    my $tree_cols = [];
    foreach my $zone_label (split /,/, $self->zones) {
        my ($language, $selector) = split /_/, $zone_label;
        my $tree = $bundle->get_tree($language, 't', $selector);
        push @all_trees, $tree;

        if (defined $prev_tree) {
            my @alilines = $self->align_to_lines($prev_tree, $language, $selector);
            my @padded_alilines = $self->_add_padding(\@alilines);
            push @$tree_cols, \@padded_alilines;
        }

        my @lines = $self->tree_to_lines($tree);
        my @padded_lines = $self->_add_padding(\@lines);
        push @$tree_cols, \@padded_lines;

        $prev_tree = $tree;
    }
    
    my @sizes = map {$self->_length($_->[0])} @$tree_cols;
    my $colsep = " "x$self->colspace;
    my $text = "";
    for (my $i = 0; $i < max(map {scalar(@$_)} @$tree_cols); $i++) {
        my $full_line = join $colsep, map {$tree_cols->[$_][$i] // " "x$sizes[$_]} (0 .. $#$tree_cols);
        $text .= $full_line . "\n";
    }
    # Print headers (if required) and the tree itself
    say { $self->_file_handle } '# sent_id = ' . $bundle->get_position()       if $self->print_sent_id;
    if ($self->print_sentence) {
        say { $self->_file_handle } '# '.$_->get_label.' = ' . $_->sentence for (map {$_->get_zone} @all_trees);
    }
    print { $self->_file_handle } $text;
    print { $self->_file_handle } "\n" if $self->add_empty_line;
}

sub tree_to_lines {
    my ($self, $root) = @_;
    my @all = $root->get_descendants({ordered=>1, add_self=>1});
    my $index_of = { map {$all[$_] => $_} (0..$#all) };
    my @lines = ('') x @all;

    # Precompute the number of non-projective gaps for each subtree
    my $gaps = {};
    _compute_gaps($root, $gaps, $index_of) if $self->minimize_cross;

    # Precompute lines for printing
    my @stack = ($root);
    while (my $node = pop @stack) {
        my @children = $node->get_children({ordered=>1, add_self=>1});
        my ($min_idx, $max_idx) = map {$index_of->{$_}} @children[0, -1];
        my $max_length = max( map{$self->_length($lines[$_])} ($min_idx..$max_idx) );
        for my $idx ($min_idx..$max_idx) {
            my $idx_node = $all[$idx];
            my $filler = $lines[$idx] =~ m/[─┌└├]$/ ? '─' : ' ';
            $lines[$idx] .= $filler x ($max_length - $self->_length($lines[$idx]));

            my $min = ($idx == $min_idx);
            my $max = ($idx == $max_idx);
            if ($idx_node == $node) {
                $lines[$idx] .= $DRAW[$max][$min] . $self->node_to_string($node);
            } else {
                if ($idx_node->parent != $node){
                    $lines[$idx] .= $V;
                } else {
                    $lines[$idx] .= $SPACE[$max][$min];
                    if ($idx_node->is_leaf){
                        $lines[$idx] .= $H . $self->node_to_string($idx_node);
                    } else {
                        push @stack, $idx_node;
                    }
                }
            }
        }

        # sorting the stack to minimize crossings of edges
        @stack = sort {$gaps->{$b} <=> $gaps->{$a}} @stack if $self->minimize_cross;
    }
    return @lines;

}

# Render a node with its attributes
sub node_to_string {
    my ($self, $node) = @_;
    return '' if $node->is_root;
    my @values = $node->get_attrs(@ATTRS, {undefs => $self->print_undef_as});
    if ($self->color){
        for my $i (0..$#ATTRS){
            my $attr = $ATTRS[$i];
            if (my $color = $COLOR_OF{$attr}){
                $values[$i] = colored($values[$i], $color);
            }
        }
    }
    return join ' ', @values;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::TextModeTrees - print legible dependency trees

=head1 SYNOPSIS

 # from command line (visualize CoNLL-U files)
 treex Write::TextModeTrees color=1 - file.treex | less -R

 # is scenario (examples of other parameters)
 Write::TextModeTrees indent=1 print_sent_id=1 print_sentence=1
 Write::TextModeTrees zones=en,cs attributes=form,lemma,tag minimize_cross=0

=head1 DESCRIPTION

This block prints dependency trees in plain-text format.
For example the following CoNLL-U file (with tabs instead of spaces)

 1  The        the        DET   _ _ 2  det       _ _
 2  third      third      ADJ   _ _ 5  nsubjpass _ _
 3  was        be         AUX   _ _ 5  aux       _ _
 4  being      be         AUX   _ _ 5  auxpass   _ _
 5  run        run        VERB  _ _ 0  root      _ _
 6  by         by         ADP   _ _ 8  case      _ _
 7  the        the        DET   _ _ 8  det       _ _
 9  of         of         ADP   _ _ 12 case      _ _
 8  head       head       NOUN  _ _ 5  nmod      _ _
 10 an         a          DET   _ _ 12 det       _ _
 11 investment investment NOUN  _ _ 12 compound  _ _
 12 firm       firm       NOUN  _ _ 8  nmod      _ SpaceAfter=No
 13 .          .          PUNCT _ _ 5  punct     _ _

will be printed (with the default parameters) as

 ─┐
  │   ┌──The DET det
  │ ┌─┘third ADJ nsubjpass
  │ ├──was AUX aux
  │ ├──being AUX auxpass
  └─┤run VERB root
    │ ┌──by ADP case
    │ ├──the DET det
    ├─┤head NOUN nmod
    │ │ ┌──of ADP case
    │ │ ├──an DET det
    │ │ ├──investment NOUN compound
    │ └─┘firm NOUN nmod
    └──. PUNCT punct

This block's method C<process_tree> can be called on any node (not only root),
which is useful for printing subtrees using C<$node-E<gt>print_subtree()>,
which is internally implemented using this block.

=head1 PARAMETERS

=head2 print_sent_id

Print ID of the tree (its root, aka "sent_id") above each tree? Default = 0.

=head2 print_sentence

Print plain-text detokenized sentence on one line above each tree? Default = 0.

=head2 add_empty_line

Print an empty line after each tree? Default = 1.

=head2 indent

Number of characters to indent node depth in the tree for better readability.
Default = 1.

=head2 minimize_cross

Minimize crossings of edges in non-projective trees? Default = 1.
Trees without crossings are subjectively more readable,
but usually in practice also "deeper", that is with higher maximal line length.

=head2 color

Print the node attribute with ANSI terminal colors?
Note that unlike in L<Udapi::Block::Write::TextModeTrees>,
here I was too lazy to implement the value 'auto',
which means that color output only if the output filehandle
is interactive (console).
Each attribute is assigned a color (the mapping is
tested on black background terminals and can be changed only in source code).

If you plan to pipe the output (e.g. to "less -R") and you want the colors,
you need to set explicitly C<color=1>, see the example in Synopsis.

=head2 attributes

A comma-separated list of node attributes which should be printed.
Default = 'form,tag,deprel'.
Possible values are I<ord, form, lemma, tag, deprel, afun, conll/cpos,...>.

=head2 print_undef_as

What should be printed instead of undefined attribute values (if any)?
Default = empty string.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
based on L<Udapi::Block::Write::TextModeTrees>
based on L<Treex::Block::Write::TreesTXT> by Matyáš Kopp

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

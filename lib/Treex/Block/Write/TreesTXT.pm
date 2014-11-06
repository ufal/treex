package Treex::Block::Write::TreesTXT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has 'tree_ids' => ( isa => 'Bool', is => 'ro', default => 0 );

has 'afuns' => ( isa => 'Bool', is => 'ro', default => 0 );

has 'indent' => (isa => 'Int', is => 'ro', default => 1, documentation => 'number of columns for better readability');

use constant {
        PRINT     => 0,
        ANODE     => 1,
        PARENT    => 2,
        SONS      => 3,
        INDEX     => 4,
        PRINTED   => 5,
        LEFTMOST  => 6,
        RIGHTMOST => 7,
        DEPTH     => 8,
    };

my $H  = "\x{2500}"; # ─
my $V  = "\x{2502}"; # │
my $LT = "\x{2518}"; # ┘
my $LB = "\x{2510}"; # ┐
my $RB = "\x{250C}"; # ┌
my $RT = "\x{2514}"; # └
my $RV = "\x{251C}"; # ├
my $LV = "\x{2524}"; # ┤
my $HB = "\x{252C}"; # ┬
my $HT = "\x{2534}"; # ┴
my $HV = "\x{253C}"; # ┼

sub BUILD {
    my ($self) = @_;
    my $indent = $self->indent;
    if ($indent){
        for my $line_sign ($H, $LT, $LB, $LV, $HB, $HT, $HV){
            $line_sign = ('─' x $indent) . $line_sign;
        }
        for my $space_sign ($V, $RB, $RT, $RV){
            $space_sign = (' ' x $indent) . $space_sign;
        }
    }
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    # Initialize data structures
    my @tree = ( [(undef) x 9] );
    $tree[0]->[INDEX] = 0;
    $tree[0]->[PRINT] = "";
    $tree[0]->[ANODE] = undef;
    $tree[0]->[PARENT] = 0;
    $tree[0]->[SONS] = [];
    $tree[0]->[PRINTED] = 0;
    $tree[0]->[LEFTMOST] = 0;
    $tree[0]->[RIGHTMOST] = 0;
    $tree[0]->[DEPTH] = 0;

    my @stack;
    push @stack, $tree[0];

    foreach my $anode ($atree->get_descendants) {
        my $index = $anode->ord;
        $tree[$index] = [(undef) x 9];
        $tree[$index]->[INDEX] = $index;
        $tree[$index]->[LEFTMOST] = $index;
        $tree[$index]->[RIGHTMOST] = $index;
        $tree[$index]->[PRINT] = "";
        $tree[$index]->[ANODE] = $anode;
        $tree[$index]->[PARENT] = $anode->get_parent->ord;
        $tree[$index]->[SONS] = [];
        $tree[$index]->[PRINTED] = 0;
        $tree[$index]->[DEPTH] = 0;
    }

  
    my $maxDepth=[map {[ (0) x $_ ]} reverse(1..(@tree+1))];
    for my $index (1..$#{\@tree}){
        push(@{$tree[$tree[$index]->[PARENT]]->[SONS]}, $tree[$index]);
    } 
    fillLeftRightMost($tree[0]);
    
    # Precompute lines for printing
    while(my $node = pop @stack) {
        my ($top,$bottom) = (0,0);
        my $append=' ';
        my $minSonOrSelf = min($node->[INDEX],(@{$node->[SONS]},($node))[0]->[INDEX]);
        my $maxSonOrSelf = max($node->[INDEX],(($node),@{$node->[SONS]})[-1]->[INDEX]);
        my $fillLen = $tree[$minSonOrSelf]->[DEPTH];
        $fillLen=max($fillLen,$tree[$_]->[DEPTH]) for ($minSonOrSelf..$maxSonOrSelf);
        for my $idx ($minSonOrSelf..$maxSonOrSelf) {
            $append = ' ';
            $append = $H if $tree[$idx]->[PRINT] =~ m/[${H}${RT}${RB}${RV}]$/;
            $tree[$idx]->[PRINT] .= "$append"x($fillLen-length($tree[$idx]->[PRINT])); ## justify to $fillLen
        }
  
        $node->[PRINTED]=1 ;
        
        # printing from leftmost son       SYMETRIC
        $append=' ';
        for my $idx ($minSonOrSelf..($node->[INDEX] - 1)) {
            $append = $V  if $top;
            if($tree[$idx]->[PARENT] == $node->[INDEX]) {
                $append = $RB;
                $append = $RV if $top;
                $top=1;
                if($tree[$idx]->[LEFTMOST] == $tree[$idx]->[RIGHTMOST]){
                    $append .= $H . $self->nodeToString($tree[$idx]->[ANODE]);
                    $tree[$idx]->[PRINTED] = 1;
                } 
                push @stack, $tree[$idx]  unless $tree[$idx]->[PRINTED];
            }
            $tree[$idx]->[PRINT] .= $append;
            $tree[$idx]->[DEPTH] = length($tree[$idx]->[PRINT] );
        }

        # printing from rightmost son       SYMETRIC
        $append=' ';
        for my $idx (reverse(($node->[INDEX] + 1)..$maxSonOrSelf)) {
            $append = $V  if $bottom;
            if($tree[$idx]->[PARENT] == $node->[INDEX]) {
                $append = $RT;
                $append = $RV if $bottom;
                $bottom = 1;
                if($tree[$idx]->[LEFTMOST] == $tree[$idx]->[RIGHTMOST]){
                    $append .= $H . $self->nodeToString($tree[$idx]->[ANODE]);
                    $tree[$idx]->[PRINTED] = 1;
                } 
                push @stack, $tree[$idx] unless $tree[$idx]->[PRINTED];
            }
            $tree[$idx]->[PRINT] .= $append;
            $tree[$idx]->[DEPTH] = length($tree[$idx]->[PRINT] );
        }

        # printing node      
        $node->[PRINT] .= ($bottom ? ($top ? $LV : $LB):($top ? $LT : $H)) . $self->nodeToString($node->[ANODE]);
        $node->[DEPTH] = length($node->[PRINT]);

        # sorting stack to minimize crossing of edges
        @stack = sort {compareNode($a,$b);} @stack; ## TODO convert to heap !!!
    }

    # Print the trees out
    if ( $self->tree_ids ){
        print { $self->_file_handle } "\n" . $atree->id . "\n";
    }  
    for my $node  (@tree) {
        print { $self->_file_handle } "$node->[PRINT]\n" ;  
    }
}

sub fillLeftRightMost {
    my $node = shift;
  
    my @nodes=@{$node->[SONS]};
    return unless @nodes;
    for my $son (@nodes) {
        fillLeftRightMost($son);
        $node->[LEFTMOST] = min($node->[LEFTMOST] ,$son->[INDEX]);
        $node->[RIGHTMOST] = max($node->[RIGHTMOST] ,$son->[INDEX]);
    }
}

sub compareNode {
    my ( $a, $b ) = @_;
    return ($a->[INDEX] < $b->[INDEX] and $a->[RIGHTMOST] < $b->[INDEX])
        #or 
        #($a->[INDEX] > $b->[INDEX] and $a->[INDEX] > $b->[RIGHTMOST])
        or
        ($a->[INDEX] > $b->[INDEX] and $a->[LEFTMOST] < $b->[INDEX])
        #or 
        #($a->[INDEX] > $b->[INDEX] and $a->[INDEX] > $b->[LEFTMOST])
        ;
}

# Return word form and tag (and optionally afun/deprel)
sub nodeToString {
    my ($self, $anode) = @_;    
    return '' if (!$anode);  # for roots
    
    my $str = $anode->form // '';
    if ($anode->tag){
        #$str .= '(' . ($anode->tag // $anode->conll_pos );
        $str .= '(' . $anode->tag;
        if ($self->afuns){
            if ($anode->afun){
                $str .= '/' . $anode->afun;
            }
            else {
                $str .= '/' . $anode->conll_deprel if $anode->conll_deprel;
            }
        }
        $str .= ')';
    }
    return $str;
}


1;

__END__

=head1 NAME

Treex::Block::Write::TreesTXT - legible dependency trees 

=head1 SYNOPSIS

 # print a.conll in a readable format
 treex Read::CoNLLX from=a.conll Write::TreexTXT indent=1 tree_ids=1 afuns=1
 
=head1 DESCRIPTION

Trees written in plain text format format.

For example the following conll file (with tabs instead of spaces)

 1  We         PRP  _ _ _ 2  SBJ
 2  gave       VBD  _ _ _ 0  ROOT
 3  Kennedy    NNP  _ _ _ 2  IOBJ
 4  no         DT   _ _ _ 7  NMOD
 5  very       RB   _ _ _ 6  AMOD
 6  positive   JJ   _ _ _ 7  NMOD
 7  approval   NN   _ _ _ 2  OBJ
 8  in         IN   _ _ _ 2  ADV
 9  the        DT   _ _ _ 10 NMOD
 10 margin     NN   _ _ _ 8  PMOD
 11 of         IN   _ _ _ 10 NMOD
 12 his        PRP$ _ _ _ 13 NMOD
 13 preferment NN   _ _ _ 11 PMOD

will be printed (with indent=1 afuns=1) as

 ─┐
  │ ┌──We(PRP/SBJ)
  └─┤gave(VBD/ROOT)
    ├──Kennedy(NNP/IOBJ)
    │ ┌──no(DT/NMOD)
    │ │ ┌──very(RB/AMOD)
    │ ├─┘positive(JJ/NMOD)
    ├─┘approval(NN/OBJ)
    └─┐in(IN/ADV)
      │ ┌──the(DT/NMOD)
      └─┤margin(NN/PMOD)
        └─┐of(IN/NMOD)
          │ ┌──his(PRP$/NMOD)
          └─┘preferment(NN/PMOD)

=head1 PARAMETERS

=over

=item tree_ids

If set to 1, print tree (root) ID above each tree.

=item afuns

If set to 1, print Afuns (or CoNLL deprels) along with word forms and tags 

=item indent

number of characters to indent node depth in the tree for better readability

=back

=head1 AUTHORS

Matyáš Kopp

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

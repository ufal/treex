package Treex::Block::Write::TreesTXT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

use constant {
        PRINT     => 0,
        WORD      => 1,
        CAT       => 2,
        PARENT    => 3,
        SONS      => 4,
        INDEX     => 5,
        PRINTED   => 6,
        LEFTMOST  => 7,
        RIGHTMOST => 8,
        DEPTH     => 9,
    };

use constant {
        H  => "\x{2500}",
        V  => "\x{2502}",
        LT => "\x{2518}",
        LB => "\x{2510}",
        RB => "\x{250C}",
        RT => "\x{2514}",
        RV => "\x{251C}",
        LV => "\x{2524}",
        HB => "\x{252C}",
        HT => "\x{2534}",
        HV => "\x{253C}"
    };
    
sub process_atree {
    my ( $self, $atree ) = @_;

    my @tree = ( [(undef) x 10] );
    $tree[0]->[INDEX] = 0;
    $tree[0]->[PRINT] = "";
    $tree[0]->[WORD] = "";
    $tree[0]->[CAT] = "";
    $tree[0]->[PARENT] = 0;
    $tree[0]->[SONS] = [];
    $tree[0]->[PRINTED] = 0;
    $tree[0]->[LEFTMOST] = 0;
    $tree[0]->[RIGHTMOST] = 0;
    $tree[0]->[DEPTH] = 0;

    my @stack;
    push @stack, $tree[0];

    foreach my $node ($atree->get_descendants) {
        my $index = $node->ord;
        $tree[$index] = [(undef) x 10];
        $tree[$index] ->[INDEX] = $index;
        $tree[$index] ->[LEFTMOST] = $index;
        $tree[$index] ->[RIGHTMOST] = $index;
        $tree[$index]->[PRINT] = "";
        $tree[$index]->[WORD] = $node->form;
        $tree[$index]->[CAT] = $node->tag;
        $tree[$index]->[PARENT] = $node->get_parent->ord;
        $tree[$index]->[SONS] = [];
        $tree[$index]->[PRINTED] = 0;
        $tree[$index]->[DEPTH] = 0;
    }

  
    my $maxDepth=[map {[ (0) x $_ ]} reverse(1..(@tree+1))];
    for my $index (1..$#{\@tree}){
        push(@{$tree[$tree[$index]->[PARENT]]->[SONS]}, $tree[$index]);
    } 
    fillLeftRightMost($tree[0]);
    
    while(my $node = pop @stack) {
        my ($top,$bottom) = (0,0);
        my $append=' ';
        my $minSonOrSelf = min($node->[INDEX],(@{$node->[SONS]},($node))[0]->[INDEX]);
        my $maxSonOrSelf = max($node->[INDEX],(($node),@{$node->[SONS]})[-1]->[INDEX]);
        my $fillLen = $tree[$minSonOrSelf]->[DEPTH];
        $fillLen=max($fillLen,$tree[$_]->[DEPTH]) for ($minSonOrSelf..$maxSonOrSelf);
        for my $idx ($minSonOrSelf..$maxSonOrSelf) {
            $append = ' ';
            $append = H if $tree[$idx]->[PRINT] =~ m/[${\(H)}${\(RT)}${\(RB)}${\(RV)}]$/;
            $tree[$idx]->[PRINT] .= "$append"x($fillLen-length($tree[$idx]->[PRINT])); ## justify to $fillLen
        }
  
        $node->[PRINTED]=1 ;
        
        # printing from leftmost son       SYMETRIC
        $append=' ';
        for my $idx ($minSonOrSelf..($node->[INDEX] - 1)) {
            $append = V  if $top;
            if($tree[$idx]->[PARENT] == $node->[INDEX]) {
                $append = RB;
                $append = RV if $top;
                $top=1;
                if($tree[$idx]->[LEFTMOST] == $tree[$idx]->[RIGHTMOST]){
                    $append .= H.nodeToString($tree[$idx]);
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
            $append = V  if $bottom;
            if($tree[$idx]->[PARENT] == $node->[INDEX]) {
                $append = RT;
                $append = RV if $bottom;
                $bottom = 1;
                if($tree[$idx]->[LEFTMOST] == $tree[$idx]->[RIGHTMOST]){
                    $append .= H.nodeToString($tree[$idx]);
                    $tree[$idx]->[PRINTED] = 1;
                } 
                push @stack, $tree[$idx] unless $tree[$idx]->[PRINTED];
            }
            $tree[$idx]->[PRINT] .= $append;
            $tree[$idx]->[DEPTH] = length($tree[$idx]->[PRINT] );
        }

        # printing node      
        $node->[PRINT] .= ($bottom ? ($top ? LV : LB):($top ? LT : H)) .nodeToString($node);
        $node->[DEPTH] = length($node->[PRINT]);

        # sorting stack to minimize crossing of edges
        @stack = sort {compareNode($a,$b);} @stack; ## TODO convert to heap !!!
    }

    # printing tree  
    for my $node  (@tree) {
        print "$node->[PRINT]\n" ;  
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

sub nodeToString {
    my $node = shift;
    return "$node->[WORD]".($node->[CAT] ? "($node->[CAT])":"");
}

1;

__END__

=head1 NAME

Treex::Block::Write::TreesTXT

=head1 DESCRIPTION

Trees written in TXT format.

=head1 AUTHOR

Matyáš Kopp, David Mareček

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

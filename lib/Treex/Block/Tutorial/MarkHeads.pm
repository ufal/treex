package Treex::Block::Tutorial::MarkHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_pnode {
    my ( $self, $pnode ) = @_;
    my @children = $pnode->get_children();
    return if !@children;
    my $phrase = $pnode->phrase;
    my $head;

    # YOUR_TASK: Mark one of the @children as head.
    # You can edit the following code or rather start from scratch.

    # Some phrases tend to be head-final
    if ($phrase =~ /^(S|NP|WHNP)$/){
        $head = $children[-1]; # Mark the last child as head
    }

    # while other phrases tend to be head-initial 
    else {
        $head = $children[0];  # Mark the first child as head
    }
    
    $head->set_is_head(1);
    
    return;
}

1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::MarkHeads - find heads of constituents

=head1 NOTE

This is just a tutorial template for L<Treex::Tutorial>.
You must fill in the code marked as YOUR_TASK.
The solution can be found in L<Treex::Block::Tutorial::Solution::MarkHeads>.

=head1 DESCRIPTION

This block should mark for each constituent in p-trees exactly one of its children
(terminal or nonterminal) as the head (using C<< $head->set_is_head(1) >>).
The block should work for PennTB-like annotation (tagset, phrase labels, function labels).
You can test it with

 treex -s -Len Tutorial::MarkHeads -- data/penntb*.mrg
 ttred data/penntb*.treex.gz

=head1 HINT 1

You can use your linguistic knowledge/intuition
and design simple heuristic rules.
For example: the head's phrase name (or tag in case of terminals)
tends to be similar to the parent's phrase
(head of VP starts with V, head of NP starts with N, head of PP...).

=head1 HINT 2

There is a lot of related work on finding heads in constituency trees
and conversion to dependency trees
(e.g. Magerman, 1994; Collins, 1999; Yamada and Matsumoto, 2003).
You can adapt "head percolation rules" defined there.
One popular implementation (PennConverter) is described in:

Richard Johansson and Pierre Nugues:
Extended Constituent-to-Dependency Conversion for English
L<http://www.df.lth.se/~richardj/pdf/nodalida2007.pdf>

=head1 HINT 3

If you decided to follow HINT 2, you can use this code snippet:

 my $RULES = <<'END_OF_RULES';
ADJP    r NNS QP NN $ ADVP JJ VBN VBG ADJP JJR NP JJS DT FW RBR RBS SBAR RB
ADVP    l RB RBR RBS FW ADVP TO CD JJR JJ IN NP JJS NN
CONJP   l CC RB IN
FRAG    l (NN.*|NP) W* SBAR (PP|IN) (ADJP|JJ) ADVP RB
INTJ    r .*
LST     l LS :
NAC     r NN.* NP NAC EX \$ CD QP PRP VBG JJ JJS JJR ADJP FW
NP      r (NN.*|NX) JJR CD JJ JJS RB QP NP- NP
NX      r (NN.*|NX) JJR CD JJ JJS RB QP NP- NP
PRT     l RP
QP      r $ IN NNS NN JJ RB DT CD NCD QP JJR JJS
RRC     l VP NP ADVP ADJP PP
S       r VP .*-PRD S SBAR ADJP UCP NP
SBAR    r S SQ SINV SBAR FRAG IN DT
SBARQ   r SQ S SINV SBARQ FRAG
SINV    r VBZ VBD VBP VB MD VP .*-PRD S SINV ADJP NP
SQ      r VBZ VBD VBP VB MD .*-PRD VP SQ
UCP     l .*
VP      l VBD VBN MD VBZ VB VBG VBP VP .*-PRD ADJP NN NNS NP
WHADJP  r CC WRB JJ ADJP
WHADVP  l CC WRB
WHNP    r NN.* WDT WP WP\$ WHADJP WHPP WHNP
X       l .*
PP      l TO IN (VBG|VBN) RP PP NN.* JJ RB
WHPP    l IN|TO
PRN     r .* 
END_OF_RULES
  
 my %rules_for;
 for my $line (split /\n/, $RULES){
     my ($phrase, $dir, @patterns) = split /\s+/, $line;
     $rules_for{$phrase} = [$dir, \@patterns];
 }



=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

############################################################
# SPOILER ALERT:                                           #
# This is a solution of Treex::Block::Tutorial::MarkHeads  #
############################################################

package Treex::Block::Tutorial::Solution::MarkHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_pnode {
    my ( $self, $pnode ) = @_;
    my @children = $pnode->get_children();
    return if !@children;

    # Mark one of the @children as head.
    my $head = $self->find_head($pnode->phrase, @children);
    $head->set_is_head(1);
    
    return;
}

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

sub find_head {
    my ($self, $phrase, @children) = @_;
    return $children[0] if @children == 1;
    my $rule = $rules_for{$phrase};
    if (!defined $rule){
        log_warn "No head-selection rule for $phrase defined";
        return $children[0];
    }
    my ($dir, $patterns) = @$rule;
    if ($dir eq 'r') {
        @children = reverse @children;
    }

    foreach my $pattern (@$patterns){
        my $head = first {$self->is_matching($_, $pattern)} @children;
        return $head if $head;
    }
    return $children[0];
}


sub is_matching {
    my ($self, $pnode, $pattern) = @_;
    my $label = $pnode->phrase || $pnode->tag;
    my ($label_regex, $function_regex) = split /-/, $pattern;
    return 0 if $label !~ /^$label_regex$/;
    return 1 if !defined $function_regex;
    my @functions = $pnode->functions ? @{$pnode->functions} : ();
    return 1 if $function_regex eq '' && @functions == 0;
    return 1 if any {$_ =~ /^$function_regex$/} @functions;
    return 0;
}

1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::Solution::MarkHeads - find heads of constituents

=head1 DESCRIPTION

This block marks for each constituent in p-trees exactly one of its children
(terminal or nonterminal) as the head (using C<< $head->set_is_head(1) >>).
The block expects PennTB-like annotation (tagset, phrase labels, function labels).

This solution uses the rules adapted from Table 1 of:

Richard Johansson and Pierre Nugues:
Extended Constituent-to-Dependency Conversion for English
L<http://www.df.lth.se/~richardj/pdf/nodalida2007.pdf>

The rules for PP, WHPP and PRN were taken from
L<http://code.google.com/p/clearparser/source/browse/trunk/config/headrule_en_ontonotes.txt>.

=head1 TODO

There are better head-finding rules (than this block or PennConverter),
see e.g. L<http://aclweb.org/anthology-new/D/D11/D11-1116.pdf>.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

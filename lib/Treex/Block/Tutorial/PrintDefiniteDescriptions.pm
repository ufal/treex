package Treex::Block::Tutorial::PrintDefiniteDescriptions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    # Select only nodes ($anode) representing the definite article,
    # i.e. exit this method if the lowercased form of $anode is not "the".
    return if lc( $anode->form ) ne 'the';

    # Let $parent be the governing node of "the".
    my $parent = $anode->get_parent();

    # YOUR TASK:
    my @description_nodes = ();

    # Print the whole sentence (useful for debugging)
    print 'SENT: ' . $anode->get_zone()->sentence . "\n";

    # Print the definite description
    print 'DESC: ';
    print join ' ', map { $_->form } ( $anode, @description_nodes, $parent );
    print "\n";

    # Print the address of $parent (useful for TrEd output)
    print $parent->get_address() . "\n";

    return;
}

1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::PrintDefiniteDescriptions

=head1 NOTE

This is just a tutorial template for L<Treex::Tutorial>.
You must fill in the code marked as YOUR_TASK.
The solution can be found in
L<Treex::Block::Tutorial::Solution::PrintDefiniteDescriptions>.

=head1 DESCRIPTION

Definite descriptions are one of the most common constructs in English.
This block should approximate definite description in a-trees as
sequences of tokens starting from "the" and ending with the determiner's
governing node.
It should print one definite description per line
(tokens separated by space).

The current implementation prints only "the" and the governing node's form.
You can test it with

 treex -Len Tutorial::PrintDefiniteDescriptions -- data/pcedt_wsj1.treex.gz

It should print:

 SENT: Pierre Vinken, 61 years old, will join the board as a nonexecutive director Nov. 29.
 DESC: the board
 data/pcedt_wsj1.treex.gz##1.EnglishA-wsj_0001-s1-t11
 SENT: Mr. Vinken is chairman of Elsevier N.V., the Dutch publishing group.
 DESC: the group
 data/pcedt_wsj1.treex.gz##2.EnglishA-wsj_0001-s2-t12
 
You can also browse the result in TrEd using
C<ttred -l data/pcedt_wsj1.treex.gz##1.EnglishA-wsj_0001-s1-t11>.
To see all the results in TrEd (using a filelist generated on the fly):

  treex -Len Tutorial::PrintDefiniteDescriptions -- data/pcedt_wsj1.treex.gz\
   | grep '^data' | ttred -l -

The node in question is highlighted in TrEd.
To see the next node, click on the button (before "printer" icon)
with tooltip "visit the next file in the file-list".

=head1 TASK A

Print the whole definite description
(including possible nested phrases left to the governing node,
but excluding all modifiers right to the governing node).
For the second sentence of F<data/pcedt_wsj1.treex.gz> you should get:

 SENT: Mr. Vinken is chairman of Elsevier N.V., the Dutch publishing group.
 DESC: the Dutch publishing group

=head1 TASK B

For the possible nested phrases in the definite description,
print only a head of the phrase.
For example for the phrase "the Environmental Protection Agency",
you should print only "the Protection Agency".
Note that the original PennTB is missing this inner noun phrase structure,
but fortunatelly there is an additional annotation by 
L<David Vadas|http://sydney.edu.au/engineering/it/~dvadas1/>.

=head1 TASK C

Detect the differences between Task A and Task B.
You should print only the definite descriptions,
which are missing one ore more nested phrases
(without those phrases, as in B).
You should find three such differences in F<data/pcedt_wsj3.treex.gz>.

=head1 HINTS

Read the following documentation:

L<Treex::Core::Node>: check methods C<get_children()> and C<get_descendants()>,
read about the "switches" which can parametrize those methods.

L<Treex::Core::Node::Ordered>:
you apply methods of this Moose role for any a-node (or t-node),
check the method C<precedes($another_node)>. 

For debugging, you can use the method
C<get_subtree_string()> (described in L<Treex::Core::Node::A>).

You can use standard Perl functions C<grep> (see C<perldoc -f grep>)
and C<any> (see L<List::MoreUtils>). 

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::Tutorial::ReorderSVO2SOV;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# This soubroutine will be applied on each node of all dependency trees (a-trees).
sub process_anode {
    my ( $self, $anode ) = @_;

    # If the current word ($anode) is a verb, ie. its PoS tag starts with "V",
    # let's reorder its children (dependent nodes including their subtrees).
    if ( $anode->tag =~ /^V/ ) {

        #####################################################
        # YOUR_TASK: do the SVO2SOV reordering.
        # Feel free to delete the following code.
        
        # Let the array @children contain all children of $anode.
        # Parameter "ordered => 1" of the method get_children()
        # sorts the children nodes according to the surface word order.
        # See https://metacpan.org/module/Treex::Core::Node#Switches
        my @children = $anode->get_children( { ordered => 1 } );

        # Shift (i.e. reorder) each child after (i.e. right to) its parent.
        # (This will not result in SOV word order.)
        # See https://metacpan.org/module/Treex::Core::Node::Ordered
        foreach my $child ( @children ) {
            $child->shift_after_node($anode);
        }
        #####################################################

    }
    return;
}

__END__

=head1 NAME

Treex::Block::Tutorial::ReorderSVO2SOV - change word order from SVO to SOV

=head1 NOTE

This is just a tutorial template for L<Treex::Tutorial>.
You must fill in the code marked as YOUR_TASK.
The current implementation only creates flat a-trees.

The solution can be found in L<Treex::Block::Tutorial::Solution::ReorderSVO2SOV>.

=head1 MOTIVATION

During translation from an SVO-based (subject-verb-object) language (e.g. English)
to an SOV-based (subject-object-verb) language (e.g. Korean),
we might need to change the word order from SVO to SOV. 
This can be done as a preprocessing before applying SMT (e.g. Moses),
which does not need to handle the long-distance reorderings.

=head1 TESTING

 # First, parse the provided sample sentences and create data/svo.treex.gz.
 # For future debugging, it may be convenient to backup the original trees to a zone with a selector "original".
 treex -Len Read::Sentences from=data/svo.txt W2A::EN::Tokenize W2A::EN::TagMorce W2A::EN::Lemmatize W2A::EN::ParseMST\
 W2A::EN::RehangConllToPdtStyle W2A::EN::SetAfunAuxCPCoord W2A::EN::SetAfun A2A::BackupTree to_selector=original Write::Treex

 # Test your block regularly and save the result to data/sov.treex.gz.  
 treex -Len Tutorial::ReorderSVO2SOV Write::Treex to=data/sov.treex.gz -- data/svo.treex.gz

 # Now, you can inspect the result with TrEd
 ttred data/sov.treex.gz

 # or just print the reordered plain text
 treex Write::AttributeSentences layer=a attributes=form -- data/sov.treex.gz
 # You may print also the original sentences
 treex --selector=all Write::AttributeSentences layer=a attributes=form -- data/sov.treex.gz
 # You may print also other attributes
 treex -Sall Write::AttributeSentences layer=a attributes=form,lemma,afun,tag -- data/sov.treex.gz

 # You can skip the intermediate saving to sov.treex.gz
 treex -q -Len Tutorial::ReorderSVO2SOV Write::AttributeSentences layer=a attributes=form -- data/svo.treex.gz

=head1 GOAL 1

 John loves Mary  -> John Mary loves

=head1 GOAL 2
 
Auxiliary verb should stay next to the main verb:

 John has loved Mary -> John Mary loved has

=head2 GOAL 3

Let's say we want to have adverbs just before verbs:

 The land will be taken quickly -> The land quickly taken be will

=HINTS

$node->afun returns the dependency relation of a given node towards its parent

$node->ord returns an integer indicating the word-order position


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

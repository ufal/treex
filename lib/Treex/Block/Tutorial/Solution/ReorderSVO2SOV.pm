################################################################
# SPOILER ALERT:                                               #
# This is a solution of Treex::Block::Tutorial::ReorderSVO2SOV #
################################################################
package Treex::Block::Tutorial::Solution::ReorderSVO2SOV;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    # If the current word ($anode) is a verb, ie. its PoS tag starts with "V",
    if ( $anode->tag =~ /^V/ ) {

        # We could just shift the verb ($anode) after all its children (the whole subtree):
        # $anode->shift_after_subtree( $anode, { without_children => 1 } );
        # This would be enough for GOAL 1.
        # However, this would leave the auxiliary verb in wrong position.

        # Let's move all right children of a verb before the verb:
        foreach my $right_child ( $anode->get_children( { following_only => 1 } ) ) {
            $right_child->shift_before_node($anode);
        }

        # For GOAL 2: Auxiliary verbs go after the main verb
        my @children = $anode->get_children( { ordered => 1 } );
        foreach my $auxv ( grep { $_->afun eq 'AuxV' } @children ) {
            $auxv->shift_after_node($anode);
        }

        # For GOAL 3: Adverbs go just before verbs
        foreach my $adverb ( grep { $_->afun =~ /Adv|Pnom/ } @children ) {
            $adverb->shift_before_node($anode);
        }


    }
    return;
}

__END__

=head1 NAME

Treex::Block::Tutorial::Solution::ReorderSVO2SOV - change word order from SVO to SOV

=head1 TODO

Tamil is a strictly head-final language (if auxiliary verbs were treated as heads).
Explore the Tamil treebank sample from data/hamledt/ta.treex.gz.
Try to figure out the word order of dependency siblings
and improve this block so it reorders English texts into Tamil-like word order.
See A2A::ReorderHeadFinal for a possible solution.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

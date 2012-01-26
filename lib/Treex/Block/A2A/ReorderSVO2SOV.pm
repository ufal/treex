package Treex::Block::A2A::ReorderSVO2SOV;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    if ( $anode->tag =~ /^V/ ) {

        # Verbs go to the end
        #$anode->shift_after_subtree( $anode, { without_children => 1 } );
        foreach my $right_child ( $anode->get_children( { following_only => 1 } ) ) {
            $right_child->shift_before_node($anode);
        }

        # Adverbs go just before verbs
        my @children = $anode->get_children( { ordered => 1 } );
        foreach my $adverb ( grep { $_->afun =~ /Adv|Pnom/ } @children ) {
            $adverb->shift_before_node($anode);
        }

        # Auxiliary verbs go after the main verb
        foreach my $auxv ( grep { $_->afun eq 'AuxV' } @children ) {
            $auxv->shift_after_node($anode);
        }

    }
    return;
}

__END__

=head1 NAME

Treex::Block::A2A::ReorderSVO2SOV - change word order from SVO to SOV

=head1 DESCRIPTION

subject-verb-object -> subject-object-verb

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

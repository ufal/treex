package Treex::Block::A2A::ReorderSVO2SOV;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    if ( $anode->tag =~ /^V/ ) {
        foreach my $right_child ( $anode->get_children({following_only=>1}) ) {
             $right_child->shift_before_node($anode);
        }
        foreach my $adverb ( grep {$_->afun eq 'Adv'} $anode->get_children({ordered=>1}) ) {
             $adverb->shift_before_node($anode);
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

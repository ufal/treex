package Treex::Block::T2T::EN2CS::DeleteSuperfluousTnodes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $DEBUG = 0;

my %child_to_delete;

foreach my $pair (
    qw(all_right ahead_go place_take down_sit
    much_very well_as little_bit air_conditioning
    real_estate ice_cream away_throw prime_minister
    floppy_disk raw_material away_turn down_lay any_one
    away_pass very_much round_turn around_turn
    machine_gun fairy_tale down_lie good_sense honey_bee how_much
    how_many both_and)
    )
{
    my ( $child_tlemma, $parent_tlemma ) = split /_/, $pair;
    $child_to_delete{$child_tlemma}{$parent_tlemma} = 1;
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # Process only t-nodes with no children whose parent is not the root node
    return if $tnode->get_parent()->is_root();
    return if $tnode->get_children();

    my $my_lemma = $tnode->t_lemma;
    if ( $child_to_delete{$my_lemma}{ $tnode->get_parent->t_lemma } ) {
        log_info "_DELETED_\t$my_lemma\t"
            . $tnode->src_tnode->get_zone()->sentence . "\t"
            . $tnode->get_parent()->id . "\n" if $DEBUG;
        $tnode->remove();
    }

}

1;

=over

=item Treex::Block::T2T::EN2CS::DeleteSuperfluousTnodes

Deleting t-nodes that should have no counterparts on the Czech side,
such as 'place' in 'take place' or 'down' in 'sit down', and can be
deleted without any loss. Lemma pairs were manually selected from
pairs extracted from CzEng.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

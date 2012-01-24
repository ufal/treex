package Treex::Block::T2A::CS::DeleteSuperfluousPrepos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %DISTANCE_LIMIT = (
    'v'    => 5,
    'mezi' => 50,
    'pro'  => 8,
);
my $BASE_DISTANCE_LIMIT = 8;

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if !$tnode->is_coap_root();
    my @tmembers = grep { $_->is_member } $tnode->get_children();
    my @auxp_anodes =
        sort { $a->ord <=> $b->ord }
        grep { ( $_->afun || '' ) eq 'AuxP' }
        map { $_->get_aux_anodes() } @tmembers;
    return if !@auxp_anodes;

    my $first_auxp_anode = shift @auxp_anodes;
    my $prev_ord         = $first_auxp_anode->ord;
    my $limit            = $DISTANCE_LIMIT{ $first_auxp_anode->lemma } || $BASE_DISTANCE_LIMIT;

    foreach my $anode (@auxp_anodes) {
        my $ord = $anode->ord;
        return if $prev_ord + $limit < $ord
                || $anode->lemma ne $first_auxp_anode->lemma;
        $prev_ord = $ord;
    }

    foreach my $anode (@auxp_anodes) {
        foreach my $child ( $anode->get_children ) {
            if ( ( $child->afun || '' ) eq 'AuxP' ) {
                $child->remove();
            }
            else {
                $child->set_parent( $anode->get_parent );
                $child->set_is_member( $anode->is_member );
            }
        }
        $anode->remove();
    }

    return;
}

1;

=over

=item Treex::Block::T2A::CS::DeleteSuperfluousPrepos

In constructions such as 'for X and Y', the second
preposition created on the target side ('pro X a pro Y')
is removed.

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::T2A::CS::DeleteSuperfluousAuxCP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %DISTANCE_LIMIT = (
    'v'        => 5,
    'mezi'     => 50,
    'pro'      => 8,
    'protože' => 5,
);

my $BASE_DISTANCE_LIMIT = 8;

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if !$tnode->is_coap_root();
    my @tmembers = grep { $_->is_member } $tnode->get_children();
    my @auxCP_nodes =
        sort { $a->ord <=> $b->ord }
        grep { ( $_->afun || '' ) =~ /Aux[CP]/ }
        map { $_->get_aux_anodes() }
        @tmembers;
    return if !@auxCP_nodes;

    my $first_auxCP_node = shift @auxCP_nodes;
    my $afun             = $first_auxCP_node->afun;
    my $prev_ord         = $first_auxCP_node->ord;
    my $limit            = $DISTANCE_LIMIT{ $first_auxCP_node->lemma } || $BASE_DISTANCE_LIMIT;

    foreach my $anode (@auxCP_nodes) {
        my $ord = $anode->ord;
        return if $prev_ord + $limit < $ord;
        return if $anode->lemma ne $first_auxCP_node->lemma;
        $prev_ord = $ord;
    }

    my %deleted;
    foreach my $anode (@auxCP_nodes) {
        next if $deleted{$anode};
        foreach my $child ( $anode->get_children ) {
            if ( ( $child->afun || '' ) eq $afun ) {
                $child->remove();
                $deleted{$child} = 1;
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

=item Treex::Block::T2A::CS::DeleteSuperfluousAuxCP

In constructions such as 'for X and Y', the second
preposition or subordinate conjunction created on the target side ('pro X a pro Y')
is removed.

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

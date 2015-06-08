package Treex::Block::T2T::CS2RU::FixDateTime;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $t_node ) = @_;
    if ($t_node->t_lemma =~  /^[12]\d\d\d$/) {
        my $parent_god = $t_node->get_parent;
        return if $parent_god->t_lemma ne 'год';
         $parent_god->set_t_lemma($t_node->t_lemma);
        $t_node->set_t_lemma('году');

    }   
    

    return;
}


sub _rehang {
    my ( $parent, $child ) = @_;

    $child->set_parent( $parent->parent );
    $parent->set_parent($child);
    $child->set_is_member( $parent->is_member );
    $parent->set_is_member();

    return;
}


1;

=encoding utf8

=over

=item Treex::Block::T2T::CS2RU::FixDateTime

v roce 2009 -> v 2009 godu

=back

=cut

# Copyright 2008-2015 Natalia Klyueva, Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

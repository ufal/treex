package Treex::Block::T2T::EN2CS::MoveGenitivesRight;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# using internals of another block is not nice,
# but that's the place where things like "většina" are enumerated now
use Treex::Block::T2A::CS::ReverseNumberNounDependency;

use utf8;

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( $tnode->formeme =~ /^n:([237]|.*\+\d)/
         and $tnode->precedes($tnode->get_parent)
             and not Treex::Block::T2A::CS::ReverseNumberNounDependency::_should_be_governing($tnode->t_lemma)
                 and ( $tnode->get_attr('mlayer_pos') || '' ) ne 'C'
                     and $tnode->t_lemma ne '#PersPron' ) {

        my $en_tnode = $tnode->src_tnode;

        if ( ( $en_tnode and $en_tnode->formeme =~ /(adj|n):(poss|attr)/ )
                 or $tnode->src_tnode eq $tnode->get_parent->src_tnode )  {

            $tnode->shift_after_node($tnode->get_parent);

        }
    }
}


1;

=over

=item Treex::Block::T2T::EN2CS::MoveGenitivesRight

The nodes with formeme n:2, n:3, n:7 or a prepositional-group formeme,
for which the source-language formeme was n:poss or n:attr,
or which originated from hyphened English t-nodes (stock-market),
are moved behind the governing node.

Nodes that'll be later swapped with their parents (numerals and numeral-like
nouns) are excluded too.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

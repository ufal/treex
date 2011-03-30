package Treex::Block::T2T::EN2CS::MoveJesteBeforeVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $parent = $tnode->get_parent;

    if ($tnode->t_lemma eq 'ještě'
        && !$tnode->children
        && ( $parent->get_attr('gram/negation') || '' ) eq 'neg1'
        && $parent->precedes($tnode)
        )
    {
        $tnode->shift_before_node($parent);
    }
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::MoveJesteBeforeVerb

'jeste' resulting from 'not yet' is moved in front of the negated verb.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

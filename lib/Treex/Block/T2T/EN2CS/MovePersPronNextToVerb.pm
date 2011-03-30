package Treex::Block::T2T::EN2CS::MovePersPronNextToVerb;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $parent = $tnode->get_parent;
    if ($tnode->t_lemma eq '#PersPron'
        && !$parent->is_root
        && $parent->formeme =~ /^v:/
        && $tnode->formeme !~ /^n:1/
        && $tnode->ord > $parent->ord
        )
    {
        $tnode->shift_after_node($parent);
    }
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::MovePersPronNextToVerb

No-subject #PersProns which are governed by a verb are shifted nex to the verb.

=back

=cut

# Copyright 2010 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

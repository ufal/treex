package Treex::Block::T2T::EN2CS::MovePersPronNextToVerb;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $cs_troot->get_descendants ) {

        my $formeme = $cs_tnode->formeme;
        my $parent = $cs_tnode->get_parent;

        if ( $cs_tnode->t_lemma eq '#PersPron'
          && $parent ne $cs_troot  
          && $parent->formeme =~ /^v:/
          && $cs_tnode->formeme !~ /^n:1/
          && $cs_tnode->ord > $parent->ord ) {
            $cs_tnode->shift_after_node($parent);
        }
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

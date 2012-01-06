package Treex::Block::T2A::AddInterleavedFormemeNodes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $orig_troot = $bundle->get_zone($self->language)->get_ttree;
    my $inter_zone = $bundle->create_zone($self->language,'interleaved');
    my $inter_aroot = $inter_zone->create_atree;
    convert_children($orig_troot, $inter_aroot);
    foreach my $node ($inter_aroot->get_descendants) {
        my $formeme_node = $node->get_parent->create_child;
        $formeme_node->shift_before_node($node);
        $formeme_node->set_lemma($node->tag); # formeme temporarily stored in tag
        $node->set_tag(undef);
        $node->set_parent($formeme_node);
    }
}

sub convert_children {
    my ($tparent,$aparent) = @_;
    foreach my $tchild ($tparent->get_children) {
        my $achild = $aparent->create_child;
        $achild->_set_ord($tchild->ord);
        $achild->set_lemma($tchild->t_lemma);
        $achild->set_tag($tchild->formeme);
        convert_children($tchild,$achild);
    }
}

1;

=over

=item Treex::Block::T2A::AddInterleavedFormemeNodes

Copy t-tree into a-tree, and double each node:  the upper one bears the original
t-node's formeme, the lower one bears the t-node's t_lemma.

=back

=cut

# Copyright 2012 Zdenìk ®abokrtský
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::HamleDT::ZH::FixPUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # Fix tokenization.
    # Tokens with tag AFFIX:
    # - join with its dependent as one token (if it has a dependent)
    # - the new tag should be that of the dependent's
    # - the deprel + head index should be that of the AFFIX
    # After Martin's conversion, we have ToDo=affix in MISC.
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my @misc = $nodes[$i]->get_misc();
        if (any {$_ eq 'ToDo=affix'} (@misc))
        {
            # We expect the previous word to depend on us via the dep relation (suff relation in Google annotation).
            if ($i > 0 && $nodes[$i-1]->parent() == $nodes[$i] && $nodes[$i-1]->deprel() eq 'dep')
            {
                $nodes[$i-1]->set_form($nodes[$i-1]->form().$nodes[$i]->form());
                $nodes[$i-1]->set_translit($nodes[$i-1]->translit().$nodes[$i]->translit());
                $nodes[$i-1]->set_parent($nodes[$i]->parent());
                $nodes[$i-1]->set_deprel($nodes[$i]->deprel());
                # Re-attach any other children to the merged node.
                my @children = $nodes[$i]->children();
                foreach my $c (@children)
                {
                    $c->set_parent($nodes[$i-1]);
                }
                $nodes[$i]->remove();
                splice(@nodes, $i--, 1);
                $root->_normalize_node_ordering();
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::ZH::FixPUD

Fixes certain known problems with Google annotation of the Chinese part of the parallel treebank.

=back

=cut

# Copyright 2017 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

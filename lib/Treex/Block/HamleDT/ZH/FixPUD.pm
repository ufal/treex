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
    $self->fix_tokenization($root);
    $self->fix_deprels($root);
}



#------------------------------------------------------------------------------
# Merges adjacent tokens that are connected using the suff (now dep) relation.
#------------------------------------------------------------------------------
sub fix_tokenization
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
                $nodes[$i-1]->set_misc(grep {$_ ne 'OrigDeprel=suff'} ($nodes[$i-1]->get_misc()));
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



#------------------------------------------------------------------------------
# Fixes wrong dependency relation labels.
#------------------------------------------------------------------------------
sub fix_deprels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Martin/Udapi ud.Google2ud converted prt to compound:prt but it is correct only in Germanic languages.
        # We will not check compound:prt because it may be something different in the future versions.
        if ($node->form() eq '地' && $node->is_particle())
        {
            $node->set_deprel('mark:adv');
        }
        elsif ($node->form() eq m/^(雖然|盡管|儘管|無論|的話|若|假如|即使|不管|不論|一旦|不但|只要)$/)
        {
            $node->iset()->set('conjtype' => 'sub');
            $node->set_deprel('mark');
        }
        # Martin/Udapi ud.Google2ud converted vmod to acl. But Herman observed that in Chinese it should often (always?) be advcl.
        elsif ($node->deprel() eq 'acl' && !$node->parent()->is_noun())
        {
            $node->set_deprel('advcl');
        }
        # Relative adverb is not subordinating conjunction.
        elsif ($node->deprel() eq 'mark')
        {
            if ($node->is_adverb())
            {
                $node->set_deprel('advmod');
            }
        }
        # Obl:poss does not exist. Either it should be nmod:poss (and maybe the parent's POS tag is incorrect)
        # or there is a deeper problem; but then it is not clear what to do anyway. 9 occurrences.
        # Moreover, even nmod:poss is better avoided in Chinese (suggested by Herman) because the relation is often
        # a simple genitive-like modification without possessive meaning.
        elsif ($node->deprel() =~ m/^(nmod|obl):poss$/)
        {
            $node->set_deprel($1);
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

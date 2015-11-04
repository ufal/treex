package Treex::Block::HamleDT::RO::FixUD;
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
    $self->fix_features($root);
}



#------------------------------------------------------------------------------
# There are no features yet. The original ro::multext tag is in the POS column.
# We will get the features from the original tag.
#------------------------------------------------------------------------------
sub fix_features
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $src_tag = $node->conll_pos();
        # Convert the tag to Interset.
        my $f = decode('ro::multext', $src_tag);
        # Changed features may cause a change of UPOS but it is probably not desirable. Or is it?
        my $tag0 = $node->tag();
        my $tag1 = $f->get_upos();
        my @miscfeatures;
        if($tag1 ne $tag0)
        {
            # Adjust Interset to the original tag.
            $f->set_upos($tag0);
            unless($tag1 eq 'X')
            {
                unshift(@miscfeatures, "AltTag=$tag0-$tag1");
            }
        }
        $node->set_iset($f);
        ###!!! We do not check the previous contents of MISC because we know that in this particular data it is empty.
        $node->wild()->{misc} = join('|', @miscfeatures);
    }
}



1;

=over

=item Treex::Block::HamleDT::RO::FixUD

This is a temporary block used to prepare the Romanian UD 1.2 treebank.
We got the data from Verginica Mititelu. The part-of-speech tags and the
dependency relations already follow the UD guidelines. However, features have
to be converted from the original POS tag, stored in the POS column.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

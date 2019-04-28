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
    # DZ: I used the method fix_features() in 2015 to perform the initial conversion
    # of morphological features from the Romanian Multext-East tagset. Re-running
    # it now might damage later changes done by the Romanian team.
    #$self->fix_features($root);
    $self->decide_between_det_and_num($root);
}



#------------------------------------------------------------------------------
# When exporting Interset to UPOS and features, nonempty PronType co-occurring
# with NumType=Card is taken to mark a pronominal quantifier and causes the
# UPOS to be DET instead of NUM. However, the word "ambii" ("both") in Romanian
# has NumType=Card|PronType=Tot and it is treated as a numeral there, including
# the deprel 'nummod' (instead of 'det'). Therefore we should correct the tag
# to NUM (but we won't touch the features and we hope that nobody will
# regenerate UPOS from Interset again).
#------------------------------------------------------------------------------
sub decide_between_det_and_num
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->is_cardinal() && $node->is_total() && $node->deprel() !~ m/^det(:|$)/)
        {
            $node->set_tag('NUM');
        }
    }
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
            # The original tags for punctuation are not Multext-East and we could not convert them.
            # Thus we will have a random result for punctuation but we should not promote it.
            unless($tag1 eq 'X' || $tag0 eq 'PUNCT')
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

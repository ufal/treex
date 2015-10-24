package Treex::Block::HamleDT::HI::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->regenerate_upos($root);
}



#------------------------------------------------------------------------------
# After changes done to Interset (including part of speech) generates the
# universal part-of-speech tag anew.
#------------------------------------------------------------------------------
sub regenerate_upos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        $node->set_tag($node->iset()->get_upos());
    }
}



1;

=over

=item Treex::Block::HamleDT::HI::FixUD

This is a temporary block used to prepare the Hindi UD 1.2 treebank.
We got new data from Riyaz Ahmad / IIIT Hyderabad. The data is larger than the
previous Hindi data we had, and the dependency relations already follow the UD
guidelines. However, features have to be converted.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

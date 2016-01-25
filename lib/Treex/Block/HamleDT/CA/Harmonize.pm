package Treex::Block::HamleDT::CA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizeAnCora';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ca::conll2009',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Coma_Estadella , Àngel_Jové , Víctor_P._Pallarés i Josep_Guinovart
        # Angel is attached correctly to Coma but everything else is attached to Angel.
        my $form = $node->form();
        if($form eq 'Àngel_Jové')
        {
            my $parent = $node->parent();
            my $pform = $parent->form();
            if(defined($pform) && $pform eq 'Coma_Estadella')
            {
                my @children = $node->children({'ordered' => 1});
                if(scalar(@children)==5 && $node->deprel() eq 'CoordArg' && $children[2]->deprel() eq 'CoordArg')
                {
                    foreach my $child (@children)
                    {
                        $child->set_parent($parent);
                    }
                }
            }
        }
        # a finals de novembre o principis de desembre
        # Structure is correct but finals is marked as conjunct while it should bear the deprel of the coordination.
        elsif($form eq 'finals' && $node->deprel() eq 'CoordArg')
        {
            my $parent = $node->parent();
            my $pform = $parent->form();
            if(defined($pform) && $pform eq 'a')
            {
                $node->set_deprel('PrepArg');
            }
        }
        # Els presidents de les federacions de Lleida , Isidre_Gavín , Barcelona-comarques Joan_Raventós , ...
        elsif($form eq 'Isidre_Gavín')
        {
            my $parent = $node->parent();
            my $pform = $parent->form();
            if(defined($pform) && $pform eq 'Lleida')
            {
                my @children = $node->children({'ordered' => 1});
                if(scalar(@children)==2 && $children[1]->form() eq ',')
                {
                    # Joan_Raventós should be attached to Barcelona-comarques rather than to Lleida.
                    # Do this before attaching the comma to Lleida. children(ordered) does not work as expected.
                    my @siblings = $parent->children({'ordered' => 1});
                    if(scalar(@siblings)==3)
                    {
                        $siblings[2]->set_parent($siblings[1]);
                    }
                    # We need a punctuation node to head the coordination "Lleida , Barcelona-comarques".
                    $children[1]->set_parent($parent);
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::CA::Harmonize

Converts Catalan trees from CoNLL 2009 to the HamleDT (Prague) style.
Relies on code that is common for both AnCora treebanks (Catalan and Spanish).

=back

=cut

# Copyright 2011-2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

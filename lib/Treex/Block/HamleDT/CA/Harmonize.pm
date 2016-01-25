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
    # Coma_Estadella , Àngel_Jové , Víctor_P._Pallarés i Josep_Guinovart
    # Angel is attached correctly to Coma but everything else is attached to Angel.
    foreach my $node (@nodes)
    {
        if($node->form() eq 'Àngel_Jové')
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
                else
                {
                    log_fatal(scalar(@children));
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

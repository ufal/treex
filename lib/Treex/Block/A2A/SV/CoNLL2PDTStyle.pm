package Treex::Block::A2A::SV::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';



#------------------------------------------------------------------------------
# Reads the Swedish tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    # Adjust the tree structure.
    #$self->attach_final_punctuation_to_root($a_root);
    #$self->lift_noun_phrases($a_root);
    #$self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
    #$self->check_afuns($a_root);
}



1;



=over

=item Treex::Block::A2A::SV::CoNLL2PDTStyle

Converts trees coming from the Swedish Mamba Treebank via the CoNLL-X format to the style of
the Prague Dependency Treebank. Converts tags and restructures the tree.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

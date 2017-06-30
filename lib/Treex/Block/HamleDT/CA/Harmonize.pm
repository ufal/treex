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
        my $parent = $node->parent();
        my $pform = $parent->form() // '';
        if($form eq 'Àngel_Jové')
        {
            if($pform eq 'Coma_Estadella')
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
            if($pform eq 'a')
            {
                $node->set_deprel('PrepArg');
            }
        }
        # Els presidents de les federacions de Lleida , Isidre_Gavín , Barcelona-comarques Joan_Raventós , ...
        elsif($form eq 'Isidre_Gavín')
        {
            if($pform eq 'Lleida')
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
        # d' agents locals
        # dels espais públics
        # dels 20 vocals
        elsif(($form eq 'locals' && $pform eq 'agents' ||
               $form eq 'públics' && $pform eq 'espais' ||
               $form eq 'vocals' && $pform eq '20')
             && $node->deprel() eq 'CoordArg' && scalar($parent->children())==1)
        {
            $node->set_deprel('Atr');
        }
        # L' èxit va ser clar , rotund , merescut .
        # "rotund" is attached to "clar" as "grup.a" (CoordArg).
        # So should be "merescut", but its relation is labeled "participi", not "grup.a". Fix it.
        elsif($form eq 'merescut')
        {
            my $phrase = join(' ', map {$_->form()} ($node->parent()->get_descendants({'add_self' => 1, 'ordered' => 1})));
            if($phrase eq 'clar , rotund , merescut')
            {
                $node->set_deprel('CoordArg');
            }
        }
        # L' edició , en vuit volums , en català i castellà , inclourà els textos que Salvador_Dalí va escriure des_de 1919 , quan _ tenia 15 anys , fins gairebé al final de la_seva vida .
        # 1919 is the head, attached upwards as 'cc' (adjunct). Children: des_de (coord), tenia (S), fins (coord), final (sn).
        # "fins" heads the subtree "fins gairebé al". But "al" should be attached to "final" and it isn't. And it is probably better not to do it as coordination anyway.
        elsif($form eq '1919' && $self->get_node_spanstring($node) =~ m/^des_de 1919 , quan _ tenia 15 anys , fins gairebé al final de la_seva vida$/)
        {
            my @subtree = $self->get_node_subtree($node);
            my $desde = $subtree[0];
            my $fins = $subtree[9];
            my $gairebe = $subtree[10];
            my $al = $subtree[11];
            my $final = $subtree[12];
            $desde->set_parent($parent);
            $desde->set_deprel('Adv');
            $fins->set_parent($parent);
            $fins->set_deprel('Adv');
            $node->set_parent($desde);
            $node->set_deprel('PrepArg');
            $al->set_deprel('PrepArg');
            $final->set_parent($al);
            $final->set_deprel('PrepArg');
            $gairebe->set_parent($final);
            $gairebe->set_deprel('AuxZ');
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

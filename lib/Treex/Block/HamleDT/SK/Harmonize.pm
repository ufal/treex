package Treex::Block::HamleDT::SK::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

#------------------------------------------------------------------------------
# Reads the Slovak tree, converts morphosyntactic tags to the PDT tagset,
# converts afuns if applicable, transforms tree to adhere to HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone, 'snk');
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real afun. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
    # Try to fix annotation inconsistencies around coordination.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            if(!$parent->is_coap_root())
            {
                if($parent->get_iset('pos') eq 'conj' || $parent->form() =~ m/^(ani|,|;|:|-+)$/)
                {
                    $parent->set_afun('Coord');
                }
                else
                {
                    $node->set_is_member(0);
                }
            }
        }
    }
    # Now the above conversion could be trigerred at new places.
    # (But we have to do it above as well, otherwise the correction of coordination inconsistencies would be less successful.)
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
}

1;

=over

=item Treex::Block::HamleDT::SK::Harmonize

Converts SNK (Slovak National Corpus) trees to the HamleDT style. Currently
it only involves conversion of the morphological tags (and Interset decoding).

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

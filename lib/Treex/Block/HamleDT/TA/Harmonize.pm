package Treex::Block::HamleDT::TA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ta::tamiltb',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the TamilTB CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->fix_coordination($root);
}

#------------------------------------------------------------------------------
# Different source treebanks may use different attributes to store information
# needed by Interset drivers to decode the Interset feature values. By default,
# the CoNLL 2006 fields CPOS, POS and FEAT are concatenated and used as the
# input tag. If the morphosyntactic information is stored elsewhere (e.g. in
# the tag attribute), the Harmonize block of the respective treebank should
# redefine this method. Note that even CoNLL 2009 differs from CoNLL 2006.
#------------------------------------------------------------------------------
sub get_input_tag_for_interset
{
    my $self   = shift;
    my $node   = shift;
    # Even though we read the Tamil treebank converted to the CoNLL-X format,
    # we only need the contents of the POS column because the original
    # positional tag is stored there.
    return $node->conll_pos();
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
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;
        if ( $afun =~ s/_M$// )
        {
            $node->set_is_member(1);
        }
        # Certain TamilTB-specific afuns are not part of the HamleDT label set.
        # Adverbial complements and adjuncts are merged to just adverbials.
        if($afun =~ m/^(AAdjn|AComp)$/)
        {
            $afun = 'Adv';
        }
        # Adjectival participial or adjectivalized verb.
        # Most often attached to nouns.
        elsif($afun eq 'AdjAtr')
        {
            $afun = 'Atr';
        }
        # Part of a word.
        elsif($afun eq 'CC')
        {
            if($node->parent()->get_iset('pos') eq 'verb')
            {
                $afun = 'AuxT';
            }
            else
            {
                $afun = 'Atr';
            }
        }
        # Complement other than attaching to verbs.
        elsif($afun eq 'Comp')
        {
            $afun = 'Atr';
        }
        $node->set_afun($afun);
    }
}



#------------------------------------------------------------------------------
# Fixes occasional errors in analysis of coordination.
#------------------------------------------------------------------------------
sub fix_coordination
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # Fix conjuncts outside coordination.
        if($node->is_member() && $node->parent()->afun() ne 'Coord')
        {
            my $parent = $node->parent();
            if($parent->form() eq 'um' || $parent->afun() eq 'AuxX')
            {
                $parent->set_afun('Coord');
            }
            else
            {
                my $solved = 0;
                my $rs1 = $node->get_right_neighbor();
                if($rs1 && $rs1->form() eq '-')
                {
                    my $rs2 = $rs1->get_right_neighbor();
                    if($rs2->is_member())
                    {
                        $node->set_parent($rs1);
                        $rs2->set_parent($rs1);
                        $rs1->set_afun('Coord');
                        $solved = 1;
                    }
                }
                if(!$solved)
                {
                    $node->set_is_member(0);
                }
            }
        }
        # Fix coordination without conjuncts.
        if($node->afun() eq 'Coord' && !grep {$_->is_member()} ($node->children()))
        {
            my @children = $node->children();
            if(scalar(@children)==0)
            {
                $node->set_afun('AuxY');
            }
            else
            {
                $self->identify_conjuncts($node);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::TA::Harmonize

Converts TamilTB.v0.1 (Tamil Dependency Treebank) from CoNLL to the style of
HamleDT (Prague).

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

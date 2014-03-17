package Treex::Block::HamleDT::GRC::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Ancient Greek CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($a_root);
    $self->check_apos_coord_membership($a_root);
    $self->check_afuns($a_root);

    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($a_root->get_zone());
    $self->get_or_load_other_block('A2A::SetSharedModifier')->process_zone($a_root->get_zone());
    $self->get_or_load_other_block('HamleDT::SetCoordConjunction')->process_zone($a_root->get_zone());
    $self->get_or_load_other_block('HamleDT::Pdt2HamledtApos')->process_zone($a_root->get_zone());
}

sub check_apos_coord_membership {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ($afun =~ /^(Apos|Coord)$/) {
            $self->identify_coap_members($node);
        }
    }
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
        my $form   = $node->form();
        my $pos    = $node->conll_pos();

        # default assignment
        my $afun = $deprel;

        if ( $afun =~ /_CO$/ ) {
            $node->set_is_member(1);
        }

        # Remove all contents after first underscore
        if ( $afun =~ /^(([A-Za-z]+)(_AP)(_.+)?)$/ ) {
            $afun =~ s/^([A-Za-z]+)(_AP)(_.+)?$/$1_Ap/;
            $afun =~ s/^ExD_Ap/ExD/;
        }
        else {
            $afun =~ s/^([A-Za-z]+)(_.+)$/$1/;
        }

        #
        if ( $deprel =~ /^ADV/ ) {
            $afun = "Adv";
        }
        elsif ( $deprel =~ /^APOS/ ) {
            $afun = "Apos";
        }
        elsif ( $deprel =~ /^ATR/ ) {
            $afun = "Atr";
        }
        elsif ( $deprel =~ /^ATV/ ) {
            $afun = "Atv";
        }
        elsif ( $deprel =~ /^AtvV/ ) {
            $afun = "AtvV";
        }
        elsif ( $deprel =~ /^COORD/ ) {
            $afun = "Coord";
        }
        elsif ( $deprel =~ /^OBJ/ ) {
            $afun = "Obj";
        }
        elsif ( $deprel =~ /^OCOMP/ ) {
            $afun = "Obj";
        }
        elsif ( $deprel =~ /^PNOM/ ) {
            $afun = "Pnom";
        }
        elsif ( $deprel =~ /^PRED/ ) {
            $afun = "Pred";
        }
        elsif ( $deprel =~ /^SBJ/ ) {
            $afun = "Sb";
        }
        elsif ( $deprel =~ /^(UNDEFINED|XSEG|_ExD0_PRED)$/ ) {
            $afun = "Atr";
        }
        elsif ( $deprel =~ /^AuxP-CYCLE/ ) {
            $afun = "AuxP";
        }
        $node->set_afun($afun);
    }

    foreach my $node (@nodes) {
        # "and" and "but" have often deprel PRED
        if ($node->form =~ /^(και|αλλ’|,)$/ and grep {$_->is_member} $node->get_children) {
            $node->set_afun("Coord");
        }

        # no is_member allowed directly below root
        if ($node->is_member and $node->get_parent->is_root) {
            $node->set_is_member(0);
        }

    }

}

1;

=over

=item Treex::Block::HamleDT::GRC::Harmonize

Converts Ancient Greek dependency treebank into PDT style treebank. Most of the
deprel tags follows PDT convention, but they are very elaborated, and has been
shortened.

1. Morphological conversion             -> No

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes



=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::HamleDT::LA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

use Treex::Block::HamleDT::Pdt2TreexIsMemberConversion;

#------------------------------------------------------------------------------
# Reads the Latin CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    $self->check_afuns($a_root);
}

sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $ppos   = $parent->tag();
        if ( $deprel =~ /_CO$/ ) {
            $node->set_is_member(1);
        }

        #convert into PDT style
        if ( $deprel =~ 'PNOM' )
        {
            $node->set_afun('Pnom');
        }
        elsif ( $deprel =~ 'COORD' ) # ordering is important because of mixed deprels such as COORD_ExD_OBJ
        {
            $node->set_afun('Coord');
        }
        elsif ( $deprel =~ 'OBJ' )
        {
            $node->set_afun('Obj');
        }
        elsif ( $deprel =~ 'ATR' )
        {
            $node->set_afun('Atr');
        }
        elsif ( $deprel =~ 'SBJ' )
        {
            $node->set_afun('Sb');
        }
        elsif ( $deprel =~ 'AUXC' )
        {
            $node->set_afun('AuxC');
        }
        elsif ( $deprel =~ 'AuxC' )
        {
            $node->set_afun('AuxC');
        }
        elsif ( $deprel =~ 'AuxY' )
        {
            $node->set_afun('AuxY');
        }
        elsif ( $deprel =~ 'AUXP' )
        {
            $node->set_afun('AuxP');
        }
        elsif ( $deprel =~ 'AuxP' )
        {
            $node->set_afun('AuxP');
        }
        elsif ( $deprel =~ 'PRED' )
        {
            $node->set_afun('Pred');
        }
        elsif ( $deprel =~ 'ExD' )
        {
            $node->set_afun('ExD');
        }
        elsif ( $deprel =~ 'ADV' )
        {
            $node->set_afun('Adv');
        }
        elsif ( $deprel =~ 'ATV' )
        {
            $node->set_afun('Atv');
        }
        elsif ( $deprel =~ 'ATVV' )
        {
            $node->set_afun('AtvV');
        }
        elsif ( $deprel =~ 'AtvV' )
        {
            $node->set_afun('AtvV');
        }
        elsif ( $deprel =~ 'APOS' )
        {
            $node->set_afun('Apos');
        }

        #Object compliment
        elsif ( $deprel =~ 'OCOMP' )
        {
            $node->set_afun('Obj');
        }

        #not sure what XSEG is/can't find documentation on it'
        elsif ( $deprel =~ 'XSEG' )
        {
            $node->set_afun('Atr');
        }

        #undefined tags=atr?
        elsif ( $deprel =~ 'UNDEFINED' )
        {
            $node->set_afun('Apos');
        }
        else {
            $node->set_afun($deprel);
        }

    }
}

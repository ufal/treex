package Treex::Block::HamleDT::EL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    $self->hang_everything_under_pred($a_root);
    $self->attach_final_punctuation_to_root($a_root);          
    $self->check_apos_coord_membership($a_root);
    $self->get_or_load_other_block('HamleDT::Pdt2HamledtApos')->process_zone($a_root->get_zone());
    $self->check_afuns($a_root);
    
    # Error routines
    $self->remove_ismember_membership($a_root);
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

# In the original treebank, some of the nodes might be attached to technical root
# rather than with the predicate node. those nodes will
# be attached to predicate node.
sub hang_everything_under_pred {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_children();
    my @dnodes;
    my $prednode;
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $afun = $node->afun();
            my $ordn = $node->ord();
            my $parnode = $node->get_parent();
            if (defined $parnode) {
                my $ordpar = $parnode->ord();
                if ($ordpar == 0) {
                    if ($afun ne 'Pred') {
                        push @dnodes, $node
                    }
                    else {
                        $prednode = $node;
                    }                           
                }         
            }
        }
    }    
    #
    if (scalar(@dnodes) > 0) {
        if (defined $prednode) {
            foreach my $dn (@dnodes) {
                if (defined $dn) {
                    $dn->set_parent($prednode);
                }
            }
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

        $afun =~ s/^IObj/Obj/;
        $afun =~ s/_Ap$//;
        $afun =~ s/_Pa$//;

        if ( $deprel eq '---' ) {
            $afun = "Atr";
        }

        if ( $afun =~ /_Co$/ ) {
            $afun =~ s/_Co$//;
            $node->set_is_member(1);
        }

        $node->set_afun($afun);
    }
}

# error handling routines


1;

=over

=item Treex::Block::HamleDT::EL::Harmonize

Converts Modern Greek dependency treebank into PDT style treebank.

1. Morphological conversion             -> Yes 

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes



=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

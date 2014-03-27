package Treex::Block::HamleDT::EL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

#------------------------------------------------------------------------------
# Reads the Greek CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->hang_everything_under_pred($root);
    $self->check_apos_coord_membership($root);
    # Error routines
    $self->remove_ismember_membership($root);
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
        # Convert _Co and _Ap suffixes to the is_member flag.
        if($afun =~ s/_(Co|Ap)$//)
        {
            $node->set_is_member(1);
        }
        # Convert the _Pa suffix to the is_parenthesis_root flag.
        if($afun =~ s/_Pa$//)
        {
            $node->set_is_parenthesis_root();
        }
        # HamleDT currently does not distinguish direct and indirect objects.
        $afun =~ s/^IObj/Obj/;
        if ( $deprel eq '---' ) {
            $afun = "Atr";
        }
        # combined afuns (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $afun =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $afun = 'Atr';
        }
        $node->set_afun($afun);
    }
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

# error handling routines


1;

=over

=item Treex::Block::HamleDT::EL::Harmonize

Converts Modern Greek dependency treebank into the style of HamleDT (Prague).

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes



=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

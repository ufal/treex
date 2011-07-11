package Treex::Block::A2A::EL::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';


#------------------------------------------------------------------------------
# Reads the Italian CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    set_pos($a_root);
}

sub set_pos {
    my $a_root = shift;
    # Loop over tree nodes.
    foreach my $node ($a_root->get_descendants())
    {
        my $conll_cpos = $node->conll_cpos;
        my $conll_pos = $node->conll_pos;
        my $conll_feat = $node->conll_feat;
        my $conll_tag = "$conll_cpos\t$conll_pos\t$conll_feat";

        # fine grained positional tag
        my $pdt_tag = $node->conll_pos;
        #$node->set_iset($f);
        $node->set_tag($pdt_tag);
    }        
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form = $node->form();
        my $pos = $node->conll_pos();

        # default assignment
        my $afun = $deprel;
        if($afun =~ s/_Co$//)
        {
            $node->set_is_member(1);
        }
        $node->set_afun($afun);
    }
}

1;



=over

=item Treex::Block::A2A::ELL::CoNLL2PDTStyle

Converts Modern Greek dependency treebank into PDT style treebank.

1. Morphological conversion             -> No

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes



=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

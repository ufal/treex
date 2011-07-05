package Treex::Block::A2A::IT::CoNLL2PDTStyle;
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

        # trivial conversion to PDT style afun
        $afun = 'AuxV' if ($deprel eq 'aux');       # aux       -> AuxV
        $afun = 'AuxA' if ($deprel eq 'det');       # det       -> AuxA
        $afun = 'Atr' if ($deprel eq 'mod');        # mod       -> Atr
        $afun = 'AuxV' if ($deprel eq 'modal');     # modal     -> AuxV
        $afun = 'Obj' if ($deprel eq 'ogg_d');      # ogg_d     -> Obj
        $afun = 'Obj' if ($deprel eq 'ogg_i');      # ogg_i     -> Obj
        $afun = 'Pred' if ($deprel eq 'pred');      # pred      -> Pred
        $afun = 'AuxP' if ($deprel eq 'prep');      # prep      -> AuxP
        $afun = 'Sb' if ($deprel eq 'sogg');        # sogg      -> Sb

        # punctuations
        if ($deprel eq 'punc') {
            if ($form eq ',') {
                $afun = 'AuxX';
            }
            if ($form =~ /^(\?|\:|\.|\!)$/) {
                $afun = 'AuxK';
            }
            else {
                $afun = 'AuxG';
            }
        }

        # deprelation ROOT can be 'Pred'            # pred      -> Pred
        if (($deprel eq 'ROOT') && ($pos =~ /^(V.*)$/)) {
            $afun = 'Pred';
        }

        if($afun =~ s/_M$//)
        {
            $node->set_is_member(1);
        }
        $node->set_afun($afun);
    }
}

1;



=over

=item Treex::Block::A2A::IT::CoNLL2PDTStyle

Converts ISST Italian treebank into PDT style treebank.

1. Morphological conversion             -> No

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes

        a) Coordination                 -> Yes

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

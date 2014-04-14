package Treex::Block::HamleDT::EU::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'eu::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the Basque CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    $self->correct_punctuations($root);
    $self->check_coord_membership($root);
    $self->check_afuns($root);
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
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $parent = $node->parent();
        my $ppos   = $parent->get_iset('pos');
        my $conll_subpos = $node->conll_pos();
        my $conll_pos    = $node->conll_cpos();

        # default assignment
        my $afun = 'NR';

        # main predicate
        if ($deprel eq 'ROOT')
        {
            $afun = 'Pred';
        }

        # subject
        elsif ($deprel =~ m/^(ncsubj|ccomp_subj|xcomp_subj)$/)
        {
            $afun = 'Sb';
        }

        # object
        elsif ($deprel =~ m/^(ncobj|nczobj|ccomp_obj|ccomp_zobj|xcomp_obj|xcomp_zobj)$/)
        {
            $afun = 'Obj';
        }

        # apposition
        elsif ($deprel =~ m/^(apocmod|apoxmod|aponcmod|aponcpred)$/)
        {
            $afun = 'Apposition';
        }

        # negation or attribute
        elsif ($deprel eq 'ncmod')
        {
            if ($ppos eq 'noun')
            {
                $afun = 'Atr';
            }
            else
            {
                $afun = 'Neg';
            }
        }

        # determiner
        elsif ($deprel eq 'detmod')
        {
            $afun = 'Atr'; ###!!! in future probably 'AuxA';
        }

        # auxiliary verb
        elsif ($deprel eq 'auxmod')
        {
            $afun = 'AuxV';
        }

        # punctuation
        elsif ($node->is_punctuation())
        {
            # Note: The sentence-final punctuation will get the AuxK label during later processing.
            if ($form eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }

        # 1. clausal & predicative modifiers
        elsif ($deprel =~ m/^(cmod|xmod|xpred|ncpred)$/)
        {
            if ($ppos eq 'noun')
            {
                $afun = 'Atr';
            }
            else
            {
                $afun = 'Adv';
            }
        }

        # conjunct
        elsif ($deprel eq 'lot' && $parent->is_coordinator())
        {
            # Conjuncts are attached to their conjunction and labeled "lot".
            # The label of the conjunction that heads the coordination describes the relation of the coordination to its parent.
            $afun = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # other connectors # !!! TODO
        elsif ($deprel =~ m/^lot(at)?$/)
        {
            if ($node->is_noun() || $node->is_adjective() || $node->is_numeral())
            {
                $afun = 'Atr';
            }
            elsif ($node->is_adverb() || $node->is_verb())
            {
                $afun = 'Adv';
            }
            elsif ($node->is_coordinator())
            {
                ###!!! If $node is leaf, this should be probably AuxY.
                ###!!! If it has children, we should look at their part of speech. We must not set Coord here!
                ###!!! That is the job for subsequent coordination processing, which will move our afun downwards!
                $afun = 'Adv';
            }
            elsif ($node->is_subordinator())
            {
                $afun = 'AuxC';
            }
            ###!!! if? not elsif?
            # ADL = verb
            # IZE = noun
            # BST = other
            if ($conll_pos =~ m/^(ADL|IZE|BST)$/)
            {
                $afun = 'Atr';
            }
            # ADI = verb
            elsif ($conll_pos eq 'ADI')
            {
                $afun = 'Adv';
            }
            ###!!! Dosud nepodchycené případy:
            # ez Argentinan ez ACBn = not Argentine, not ACB (dolní ez je částice/lot a visí na horním ez)
            # bai Gobernuak bai oposizioak = both the government and the opposition (dolní bai je částice/lot a visí na horním bai)
            # orekatuenak , hiru astetan mailarik onena emateko dohainik onenak dituztenak , fisikoki zein psikologikoki = balanced, free of charge for three weeks to give the best of the best, both physically and psychologically
        }

        # particles
        # prtmod # !!JM TODO - "label used to mark various particles - 'badin', 'omen', etc."
        elsif ($deprel eq 'prtmod') {
            $afun = 'Atr';
        }
        # galdemod - focalizer (?)
        elsif ($deprel eq 'galdemod') {
            $afun = 'AuxZ';
        }

        # interjection # !!JM TODO - "Uf.itj_out, vydechl Petr.", "Nezmokni, Pavle.itj_out."
        if ($deprel eq 'itj_out') {
            $afun = 'Atr';
        }

        # attributes # JM not sure whether "attribute" is the right term, seems more like a part of a name
        if ($deprel eq 'entios') {
            $afun = 'Atr';
        }

        # postos # !!JM TODO - part of a complex postposition? so AuxP somewhere around?
        elsif ($deprel eq 'postos') {
            if ($pos eq 'noun') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'adv') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'adj') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'verb') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'num') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'conj' and $subpos eq 'coor') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'conj' and  $subpos eq 'sub') {
                $afun = 'AuxC';
            }
        }

        # gradmod # !!JM TODO "el graduador" - used in comparison; "very", "too much", "more", ... - probably Atr/Adv based on ppos
        elsif ($deprel eq 'gradmod') {
            if ($pos eq 'noun') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'adv') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'adj') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'verb') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'num') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'conj' and $subpos eq 'coor') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'conj' and $subpos eq 'sub') {
                $afun = 'AuxC';
            }
        }

        # menos
        elsif ($deprel eq 'menos') {
            if ($pos eq 'noun') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'adv') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'adj') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'verb') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'num') {
                $afun = 'Atr';
            }
            elsif ($pos eq 'conj' and $subpos eq 'coor') {
                $afun = 'Adv';
            }
            elsif ($pos eq 'conj' and $subpos eq 'sub') {
                $afun = 'AuxC';
            }
        }

        # haos
        elsif ($deprel eq 'haos') {
            $afun = 'Adv';
        }

        $node->set_afun($afun);
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Basque
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_alpino($node);
    $coordination->capture_commas();
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_conjuncts();
    push(@recurse, $coordination->get_shared_modifiers());
    return @recurse;
}



# punctuations such as "," and ";" hanging under a node will be
# attached to the parents parent node
sub correct_punctuations {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $afun = $node->afun();
            my $ordn = $node->ord();
            if ($afun =~ /^(AuxX|AuxG|AuxK|AuxK)$/) {
                my $parnode = $node->get_parent();
                if (defined $parnode) {
                    my $parparnode = $parnode->get_parent();
                    if (defined $parparnode) {
                        my $ordpp = $parparnode->ord();
                        if ($ordpp > 0) {
                            $node->set_parent($parparnode);
                        }
                    }
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::EU::Harmonize

Converts trees coming from the Basque Dependency Treebank via the CoNLL-X format to the style of
HamleDT (Prague). Converts the tags and restructures the tree.

=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# Copyright 2014 Jan Mašek <masek@ufal.mff.cuni.cz>
# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

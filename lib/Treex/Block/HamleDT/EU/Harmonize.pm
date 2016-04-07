package Treex::Block::HamleDT::EU::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::AlpinoToPrague;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'eu::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
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
    # Phrase-based implementation of tree transformations (5.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::AlpinoToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->correct_punctuations($root);
    $self->check_coord_membership($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://ixa.si.ehu.es/Ixa/Argitalpenak/Barne_txostenak/1068549887/publikoak/guia.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $form   = $node->form();
        my $pos    = $node->get_iset('pos');
        # my $subpos = $node->get_iset('subpos'); # feature deprecated
        my $parent = $node->parent();
        my $ppos   = $parent->get_iset('pos');
        my $conll_subpos = $node->conll_pos();
        my $conll_pos    = $node->conll_cpos();

        # There was one cycle in the input data. It has been broken and attached to the root, thus we will deal with it as with a predicate.
        $deprel = 'ROOT' if ($deprel =~ m/^ncpred-CYCLE/);

        # main predicate
        if ($deprel eq 'ROOT')
        {
            $deprel = 'Pred';
        }

        # subject
        elsif ($deprel =~ m/^(ncsubj|ccomp_subj|xcomp_subj)$/)
        {
            $deprel = 'Sb';
        }

        # object
        elsif ($deprel =~ m/^(ncobj|nczobj|ccomp_obj|ccomp_zobj|xcomp_obj|xcomp_zobj)$/)
        {
            $deprel = 'Obj';
        }

        # apposition
        elsif ($deprel =~ m/^(apocmod|apoxmod|aponcmod|aponcpred)$/)
        {
            $deprel = 'Apposition';
        }

        # non-core modifier
        # attribute of noun (often noun modifying another noun)
        # adverbial of verb (including negation)
        elsif ($deprel eq 'ncmod')
        {
            if (lc($form) eq 'ez')
            {
                $deprel = 'Neg';
            }
            ###!!! Note that we would need effective parents to be able to check the real part of speech.
            ###!!! However, these will not be available until we convert coordination.
            elsif ($ppos =~ m/^(ad)?verb$/)
            {
                $deprel = 'Adv';
            }
            else # noun, adjective, numeral
            {
                $deprel = 'Atr';
            }
        }

        # determiner
        elsif ($deprel eq 'detmod')
        {
            $deprel = 'Atr'; ###!!! in future probably 'AuxA';
        }

        # auxiliary verb
        elsif ($deprel eq 'auxmod')
        {
            $deprel = 'AuxV';
        }

        # 1. clausal & predicative modifiers
        elsif ($deprel =~ m/^(cmod|xmod|xpred|ncpred)$/)
        {
            if ($ppos eq 'noun')
            {
                $deprel = 'Atr';
            }
            else
            {
                $deprel = 'Adv';
            }
        }

        # gradmod
        # DZ (based on PML-TQ observations):
        # gradmod modifies an adjective or adverb and specifies the grade of the property expressed:
        # ezin/noun???/gradmod okerragoak dira = cannot worse be
        # zertxobait/pronoun/gradmod hobea da = somewhat better is
        # oso/adv/gradmod ongi irabazi = very well earned
        # sentsazio nahikoa/adv/gradmod onak = feeling enough good
        # askoz_ere/BST/gradmod maila hobea = much level higher
        elsif ($deprel eq 'gradmod')
        {
            $deprel = 'Adv';
        }

        # conjunct attached to conjunction, particle or punctuation
        # coordinating particles: ez ... ez, bai ... bai
        # ez Argentinan ez ACBn = not Argentine, not ACB (the second "ez" is particle/lot and is attached to the first "ez"; conjuncts Argentine and ACB are also "lot")
        # bai Gobernuak bai oposizioak = both the government and the opposition
        elsif ($deprel eq 'lot' && $parent->is_coordinator() || $parent->is_punctuation() || $parent->is_particle())
        {
            # Conjuncts are attached to their conjunction and labeled "lot".
            # The label of the conjunction that heads the coordination describes the relation of the coordination to its parent.
            $deprel = 'CoordArg';
        }

        # coordinating conjunction at the beginning of the sentence (deficient sentential coordination)
        elsif ($deprel eq 'lotat')
        {
            ###!!! We should later reattach the main predicate to this conjunction as the only conjunct!
            $deprel = 'AuxY';
        }

        # other conjunctions
        elsif ($deprel eq 'lot')
        {
            my @children = $node->children();
            if (@children)
            {
                $deprel = 'AuxC';
            }
            else
            {
                $deprel = 'AuxY';
            }
        }

        # postos: argument of postposition
        # The postposition's label describes the relation of the whole phrase to its parent.
        # The noun under the postposition only has postpos.
        # Later processing will move the function down from the postposition to the noun, and the postposition will get AuxP.
        elsif ($deprel eq 'postos')
        {
            $deprel = 'PrepArg';
        }

        # menos: It seems to be (mostly) the argument of a subordinating conjunction (or a postposition); see also postos.
        # DZ (based on PML-TQ observations):
        # set bakar bat_ere galdu/menos gabe = without losing a single set (lit. set single even losing without)
        # bi set galtzen joan/menos ondotik = after going to lose the set (lit. the set to-lose going after)
        # herenegun Richardsonen aurkezpenean aurreratu/menos bezala/adv = like advancing Richardson's presentation yesterday (lit. yesterday Richardson's presentation advanced like)
        elsif ($deprel eq 'menos')
        {
            # The subordinating conjunction "baino" ("than") occurs with the BST tag (meaning "other", which does not say much).
            # Example: ondo baino hobeto = better than well (lit. well than better)
            if ($conll_pos eq 'BST' && $form eq 'baino')
            {
                $deprel = 'AuxC';
            }
            else
            {
                $deprel = 'SubArg';
            }
        }

        # particles
        # prtmod # !!JM TODO - "label used to mark various particles - 'badin', 'omen', etc."
        elsif ($deprel eq 'prtmod') {
            $deprel = 'Atr';
        }
        # galdemod - focalizer (?)
        elsif ($deprel eq 'galdemod') {
            $deprel = 'AuxZ';
        }

        # interjection # !!JM TODO - "Uf.itj_out, vydechl Petr.", "Nezmokni, Pavle.itj_out."
        elsif ($deprel eq 'itj_out') {
            $deprel = 'Atr';
        }

        # attributes # JM not sure whether "attribute" is the right term, seems more like a part of a name
        elsif ($deprel eq 'entios') {
            $deprel = 'Atr';
        }

        # haos
        elsif ($deprel eq 'haos') {
            $deprel = 'Adv';
        }

        # punctuation
        elsif ($deprel eq 'PUNC')
        {
            # Note: The sentence-final punctuation will get the AuxK label during later processing.
            if ($form eq ',')
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }

        $node->set_deprel($deprel);
    }
    # Fix known irregularities in the data.
    # Do so here, before the superordinate class operates on the data.
    $self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors and irregularities.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    my $sentence = join(' ', map {$_->form()} (@nodes));
    # The original annotation of this sentence is totally damaged and extremely nonprojective.
    if ($sentence eq 'Bistan_da ez direla herrialde horietako txapelketetako lehen hiru sailkatuak , Larretxeak eta Arrospidek ez zutelako jardun iaz , eta , Antonio Senosiain eta Xabier Orbegozo Arria V.a izan zirelako hirugarren sailkatuak .')
    {
        # ords:       1         2  3      4         5         6              7     8    9          10 11        12  13         14 15       16     17  18 19 20 21     22        23  24     25       26    27  28   29       30         31         32
        my @pord = (undef,3,    3, 0,     6,        4,        9,             8,    6,   16,        9, 12,       16, 12,        16,16,      19,    16, 19,3, 19,22,    23,       28, 25,    26,      27,   23, 19,  28,      31,        28,        0 );
        my @deprel = qw(AuxS Adv  Neg Pred  Atr       Atr       Adv            Atr   Atr  Adv        AuxX CoordArg Sb CoordArg   Neg AuxV    CoordArg Adv AuxX Obj AuxX Atr CoordArg Sb Atr  Atr      Atr   CoordArg CoordArg AuxV Atr   Adv        AuxK);
        my @tree = @nodes;
        unshift(@tree, $root);
        # To prevent cycles on the fly, first attach everything to the root, then reattach to the final parents.
        for (my $i = 1; $i <= $#tree; $i++)
        {
            $tree[$i]->set_parent($root);
        }
        for (my $i = 1; $i <= $#tree; $i++)
        {
            #my $message = "Attaching $i:".$tree[$i]->form()." to $pord[$i]:".$tree[$pord[$i]]->form()." as $deprel[$i].";
            #log_info($message);
            $tree[$i]->set_parent($tree[$pord[$i]]);
            $tree[$i]->set_deprel($deprel[$i]);
        }
    }
}



#------------------------------------------------------------------------------
# punctuations such as "," and ";" hanging under a node will be
# attached to the parents parent node
# DZ: I am not convinced that this is always the best solution. It definitely
# must not be applied in coordination!
#------------------------------------------------------------------------------
sub correct_punctuations {
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    for (my $i = 0; $i <= $#nodes; $i++) {
        my $node = $nodes[$i];
        if (defined $node) {
            my $deprel = $node->deprel();
            my $ordn = $node->ord();
            if ($deprel =~ /^(AuxX|AuxG)$/) {
                my $parnode = $node->get_parent();
                if (defined $parnode && !$parnode->is_root() && !$parnode->is_coap_root()) {
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

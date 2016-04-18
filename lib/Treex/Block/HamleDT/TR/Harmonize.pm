package Treex::Block::HamleDT::TR::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::MoscowToPrague;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'tr::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Turkish CoNLL trees, converts morphosyntactic tags to the universal
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Phrase-based implementation of tree transformations (7.3.2016).
    ###!!! The Turkish treebank differs from the default variant of the Moscow style.
    ###!!! The main difference is that it goes right-to-left. See the copy of the
    ###!!! detect_ankara() method below in this file; this has yet to be implemented
    ###!!! in Treex::Tool::PhraseBuilder.
    my $builder = new Treex::Tool::PhraseBuilder::MoscowToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
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
        my $pos    = $node->conll_pos();
        $deprel = 'Adv' if ($deprel eq 'ABLATIVE.ADJUNCT');
        $deprel = 'Apposition' if ($deprel eq 'APPOSITION');
        $deprel = 'Atr' if ($deprel eq 'CLASSIFIER');
        $deprel = 'Atr' if ($deprel eq 'COLLOCATION');
        # Coordinating conjunction or punctuation.
        if ($deprel eq 'COORDINATION')
        {
            $deprel = 'Coord';
            $node->wild()->{coordinator} = 1;
        }
        $deprel = 'Adv' if ($deprel eq 'DATIVE.ADJUNCT');
        $deprel = 'Atr' if ($deprel eq 'DETERMINER');
        $deprel = 'Atr' if ($deprel eq 'EQU.ADJUNCT');
        $deprel = 'Atr' if ($deprel eq 'ETOL');
        $deprel = 'Atr' if ($deprel eq 'DERIV');
        $deprel = 'AuxZ' if ($deprel eq 'FOCUS.PARTICLE');
        $deprel = 'Adv' if ($deprel eq 'INSTRUMENTAL.ADJUNCT');
        $deprel = 'AuxZ' if ($deprel eq 'INTENSIFIER');
        $deprel = 'Adv' if ($deprel eq 'LOCATIVE.ADJUNCT');

        # MODIFIER : Adv or Atr
        if ($deprel eq 'MODIFIER') {
            if (($node->get_iset('pos') eq 'adv')) {
                $deprel = 'Adv';
            }
            else {
                $deprel = 'Atr';
            }
        }

        $deprel = 'Neg' if ($deprel eq 'NEGATIVE.PARTICLE');

        # MODIFIER : OBJECT
        if ($deprel eq 'OBJECT') {
            my $parnode = $node->get_parent();
            if (defined $parnode) {
                my $parpos = $parnode->get_iset('pos');
                if ($parpos eq 'adp') {
                    $deprel = 'Atr';
                }
                else {
                    $deprel = 'Obj';
                }
            }
            else {
                $deprel = 'Obj';
            }
        }

        $deprel = 'Atr' if ($deprel eq 'POSSESSOR');
        $deprel = 'Atr' if ($deprel eq 'QUESTION.PARTICLE');
        $deprel = 'Atr' if ($deprel eq 'RELATIVIZER');


        # punctuations
        if ( $deprel eq 'ROOT' ) {
            if (($node->get_iset('pos') eq 'punc')) {
                if ( $form eq ',' ) {
                    $deprel = 'AuxX';
                }
                elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                    $deprel = 'AuxK';
                }
                else {
                    $deprel = 'AuxG';
                }
            }
            elsif (($node->get_iset('pos') eq 'verb')) {
                $deprel = 'Pred';
            }
            else {
                $deprel = 'Atr';
            }
        }

        # SENTENCE
        if ( $deprel eq 'SENTENCE' ) {
            if (($node->get_iset('pos') eq 'verb')) {
                $deprel = 'Pred';
            }
            elsif (($node->get_iset('pos') eq 'punc')) {
                if ( $form eq ',' ) {
                    $deprel = 'AuxX';
                }
                elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                    $deprel = 'AuxK';
                }
                else {
                    $deprel = 'AuxG';
                }

            }
            else {
                $deprel = 'Atr';
            }
        }

        $deprel = 'Atr' if ($deprel eq 'S.MODIFIER');
        $deprel = 'Sb' if ($deprel eq 'SUBJECT');
        $deprel = 'Atr' if ($deprel eq 'VOCATIVE');

        if ($node->is_adposition()) {
            $deprel = 'AuxP';
        }

        # subordinating conjunctions
        if (($node->get_iset('conjtype') eq 'sub')) {
            $deprel = 'AuxC';
        }

        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    my $sentence = join(' ', map {$_->form()} (@nodes));
    # Google translate: Do not eat me ba old man, I said, what this town was founded fairs, but never came lion.
    if($sentence =~ m/^Beni yeme be moruk , dedim , ne panay.rlar _ kuruldu bu kasabaya , ama hi.bir zaman aslan gelmedi .$/)
    {
        log_info("FIXING: $sentence");
        my $dedim = $nodes[5];
        my $comma1 = $nodes[6];
        my $kuruldu = $nodes[10];
        my $comma2 = $nodes[13];
        my $ama = $nodes[14];
        my $gelmedi = $nodes[18];
        $dedim->set_parent($comma1);
        $comma1->set_parent($kuruldu);
        $kuruldu->set_parent($comma2);
        $comma2->set_parent($ama);
        $ama->set_parent($gelmedi);
        $gelmedi->set_parent($root);
    }
}



###!!! THIS METHOD DOES NOT BELONG IN THIS CLASS. IT WAS ORIGINALLY IN
###!!! TREEX::CORE::COORDINATION (NOW DEPRECATED). WE KEEP IT HERE ONLY TO
###!!! PRESERVE THE ALGORITHM USED FOR TURKISH COORDINATION, UNTIL IT IS
###!!! IMPLEMENTED IN TREEX::TOOL::PHRASEBUILDER::BASEPHRASEBUILDER.
#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects right-to-left
# Moscow style. Coordinator (conjunction or comma) is on the path between two
# conjuncts. This style allows limited representation of nested coordination.
# It cannot distinguish ((A,B),C) from (A,B,C). Having nested coordination as
# the first conjunct is a problem. Example treebank is Turkish (METU/ODTÜ).
# - the root of the coordination is not marked
# - coordinators (either conjunctions or commas) have wild->{coordinator}
#   (the afun 'Coord' may have not survived normalization)
#   coordinator is attached to the next conjunct
# - conjuncts are not specifically marked but they can be recognized via their
#   attachment: every conjunct is attached to the following coordinator
#   the last conjunct is the head of the coordination
#   all conjuncts have the same afun: that of the whole coordination
# - if a conjunct has two or more children that are coordinators, there is
#   nested coordination. The parent conjunct first combines with the last child
#   (and its descendants, if any). The resulting coordination is a conjunct
#   that combines with the previous child (and its descendants). The process
#   goes on until all child conjuncts are processed.
# - all other children along the way are private modifiers
# The method assumes that nothing has been normalized yet. In particular it
# assumes that there are no AuxP/AuxC afuns (there are PrepArg/SubArg instead).
# Thus the method does not call $node->set/get_real_afun().
#------------------------------------------------------------------------------
sub detect_ankara
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    my $nontop = shift; # other than top level of recursion?
    log_fatal("Missing node") unless(defined($node));
    my $top = !$nontop;
    ###!!!DEBUG
    my $debug = 0;
    if($debug)
    {
        my $form = $node->form();
        $form = '' if(!defined($form));
        if($top)
        {
            $node->set_form("T:$form");
        }
        else
        {
            $node->set_form("X:$form");
        }
    }
    ###!!!END
    my @children = $node->children();
    my @conjuncts;
    my @delimiters;
    my $bottom;
    # If this is a coordinator, we expect exactly one child: the previous conjunct.
    if($node->wild()->{coordinator})
    {
        my $nc = scalar(@children);
        ###!!! There are 2662 nodes in the METU-Sabanci treebank labeled as COORDINATION.
        ###!!! Out of this number, 228 have other number of children than 1.
        ###!!! Among them are the two-word conjunctions ya-ya (either-or) and ne-ne (neither-nor).
        ###!!! The first word of the conjunction should be attached at the end of the chain as a leaf and labeled COORDINATION.
        ###!!! The other cases are annotation errors. Sometimes the conjunction is attached sidewise of the chain.
        ###!!! Sometimes a conjunction has two conjunct children (in addition to the one conjunct parent).
        ###!!! Sometimes conjunction has two children but only one is conjunct (e.g. SENTENCE) while the other has different label (e.g. S.MODIFIER).
        ###!!! Sometimes the DERIV empty nodes are included in the chain and we have to go further to find the real label.
        ###!!! Sometimes the ROOT node (usually the final punctuation) also heads a coordination of SENTENCE nodes.
        ###!!! Etc. etc. Some of the errors can be caught here, others will result in weird structrues.
        ###!!! We leave it for future work. One just cannot expect non-weird output when input is weird.
        #log_warn("Expected 1 child of coordinator, found $nc. ".$node->get_address()) if($nc!=1);
        @conjuncts = @children;
        $bottom = $nc==0;
    }
    else # not coordinator
    {
        # Are there any coordinators among the children?
        @delimiters = grep {$_->wild()->{coordinator}} @children;
        $bottom = scalar(@delimiters)==0;
    }
    if($top && $bottom)
    {
        # No participants found. This $node is not a root of coordination.
        return;
    }
    my @modifiers;
    # We can find modifiers attached to a conjunct but not to a coordinator.
    unless($node->wild()->{coordinator})
    {
        @modifiers = grep {!$_->wild()->{coordinator}} @children;
    }
    # If we are here we have participants: either conjuncts or delimiters or both.
    if($top)
    {
        # Add the root conjunct.
        # Note: root of the tree is never a conjunct! If this is the tree root, we are dealing with a deficient (probably clausal) coordination.
        unless($node->is_root())
        {
            my $orphan = 0;
            $self->add_conjunct($node, $orphan, @modifiers);
            # Save the relation of the coordination to its parent.
            $self->set_parent($node->parent());
            $self->set_afun($node->afun());
            $self->set_is_member($node->is_member());
        }
        else
        {
            ###!!! The coordination still needs to know its parent (the root) and afun (which we are guessing here but we should find a real conjunct instead).
            $self->set_parent($node);
            $self->set_afun('Pred');
            $self->set_is_member(0);
        }
    }
    # If two or more children are conjunctions or conjuncts, we have a nested coordination.
    ###!!! POZOR! Když to zůstane takhle, budeme rozpouštět vnořené koordinace!
    ###!!! Je potřeba zjistit, zda máme více než jedno dítě, které je členem koordinace.
    ###!!! Dokud máme dvě nebo více takových dětí, je třeba se spojit s prvním z nich a vytvořit vnořenou koordinaci.
    ###!!! To znamená nový objekt Coordination, kompletní běh detect_moscow2(), potom asi už i shape_prague() a novým kořenem si nahradit náš člen.
    ###!!! Další obtíž se skrývá v tom, že nás pravděpodobně zavolal někdo, kdo chce postupně rozpoznat všechny koordinace ve větě.
    ###!!! Čili jednak je tu disproporce, protože pro nevnořené koordinace si shape_prague() volá ten někdo sám.
    ###!!! A za druhé ten někdo chce pak detekci zavolat také na všechna rozvití (sdílená i soukromá) a všechny sirotky té koordinace, kterou mu vrátíme.
    ###!!! OTÁZKA: Vnořená koordinace má svá sdílená i soukromá rozvití. Dostaneme opravdu všechna do seznamu soukromých rozvití člena, který je tvořen vnořenou koordinací?
    foreach my $conjunct (@conjuncts)
    {
        my $nontop = 1;
        my @partmodifiers = $self->detect_ankara($conjunct, $nontop);
        my $orphan = 0;
        $self->add_conjunct($conjunct, $orphan, @partmodifiers);
    }
    foreach my $delimiter (@delimiters)
    {
        my $nontop = 1;
        my @partmodifiers = $self->detect_ankara($delimiter, $nontop);
        my $symbol = $delimiter->afun() =~ m/^Aux[XG]$/;
        $self->add_delimiter($delimiter, $symbol, @partmodifiers);
    }
    # If this is the top level, we now know all we can.
    # It's time for a few more heuristics.
    if($top)
    {
        $self->reconsider_distant_private_modifiers();
    }
    # Return the list of modifiers to the upper level.
    # They will need it when they add me as a participant.
    unless($top)
    {
        return @modifiers;
    }
}



1;

=over

=item Treex::Block::HamleDT::TR::Harmonize


=back

=cut

# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

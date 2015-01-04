package Treex::Block::HamleDT::CS::Udep;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'cs::pdt',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);



#------------------------------------------------------------------------------
# Reads the Czech tree and transforms it to adhere to the HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->remove_features_from_lemmas($root);
    $self->restructure_coordination_stanford($root);
    $self->push_prep_sub_down($root);
    $self->push_copulas_down($root);
    $self->afun_to_udeprel($root);
    $self->attach_final_punctuation_to_predicate($root);
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
    return $node->tag();
}



#------------------------------------------------------------------------------
# Lemmas in PDT often contain codes of additional features. Move at least some
# of these features elsewhere.
#------------------------------------------------------------------------------
sub remove_features_from_lemmas
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my %nametags =
    (
        # given name: Jan, Jiří, Václav, Petr, Josef
        'Y' => 'giv',
        # family name: Klaus, Havel, Němec, Jelcin, Svoboda
        'S' => 'sur',
        # nationality: Němec, Čech, Srb, Američan, Slovák
        'E' => 'nat',
        # location: Praha, ČR, Evropa, Německo, Brno
        'G' => 'geo',
        # organization: ODS, OSN, Sparta, ODA, Slavia
        'K' => 'com',
        # product: LN, Mercedes, Tatra, PC, MF
        'R' => 'pro',
        # other: US, PVP, Prix, Rapaport, Tour
        'm' => 'oth'
    );
    # The terminology (field) tags are not used consistently.
    # We could propose a new Interset feature to preserve them (at present it is possible to mix them with name types but I do not like it)
    # but in the current state of the annotation it is probably better to drop them completely.
    # _;[HULjgcybuwpzo]
    my %termtags =
    (
        # chemistry: H: CO, ftalát, pyrolyzát, adenozintrifosfát, CFC
        # medicine: U: AIDS, HIV, neschopnost, antibiotikum, EEG
        # natural sciences: L: HIV, neem, Homo, Buthidae, čipmank
        # justice: j: Sb, neschopnost
        # technology in general: g: ABS
        # computers and electronics: c: SPT, CD, Microsoft, MS, ROM
        # hobby, leisure, traveling: y: CD, CNN, MTV, DP, CHKO
        # economy, finance: b: dolar, ČNB, DEM, DPH, MF
        # culture, education, arts, other sciences: u: CD, AV, MK, MŠMT, proměnná
        # sports: w: MS, NHL, ME, Cup, UEFA
        # politics, government, military: p: ODS, ODA, ČSSD, EU, ČSL
        # ecology, environment: z: MŽP, CHKO
        # color indication: o: červený, infračervený, fialový, červeno
    );
    foreach my $node (@nodes)
    {
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        # Verb lemmas encode aspect.
        # Aspect is a lexical feature in Czech but it can still be encoded in Interset and not in the lemma.
        if($lemma =~ s/_:T_:W// || $lemma =~ s/_:W_:T//)
        {
            # Do nothing. The verb can have any of the two aspects so it does not make sense to say anything about it.
            # (But there are also many verbs that do not have any information about their aspect, probably due to incomplete lexicon.)
        }
        elsif($lemma =~ s/_:T//)
        {
            $iset->set('aspect', 'imp');
        }
        elsif($lemma =~ s/_:W//)
        {
            $iset->set('aspect', 'perf');
        }
        # Move the abbreviation feature from the lemma to the Interset features.
        # It is probably not necessary because the same information is also encoded in the morphological tag.
        if($lemma =~ s/_:B//)
        {
            $iset->set('abbr', 'abbr');
        }
        # According to the documentation in http://ufal.mff.cuni.cz/techrep/tr27.pdf, lemmas may also encode the part of speech:
        # _:[NAJZMVDPCIFQX]
        # However, none of these codes actually appears in PDT 3.0 data.
        # Move the foreign feature from the lemma to the Interset features.
        if($lemma =~ s/_,t//)
        {
            $iset->set('foreign', 'foreign');
        }
        # Term categories encode (among others) types of named entities.
        # There may be two categories at one lemma.
        # JVC_;K_;R (buď továrna, nebo výrobek)
        # Poldi_;Y_;K
        # Kladno_;G_;K
        my %nametypes;
        while($lemma =~ s/_;([YSEGKRm])//)
        {
            my $tag = $1;
            my $nt = $nametags{$tag};
            if(defined($nt))
            {
                $nametypes{$nt}++;
            }
        }
        # Drop the other term categories because they are used inconsistently (see above).
        $lemma =~ s/_;[HULjgcybuwpzo]//g;
        my @nametypes = sort(keys(%nametypes));
        if(@nametypes)
        {
            $iset->set('nametype', join('|', @nametypes));
            if($node->is_noun())
            {
                $iset->set('nountype', 'prop');
            }
        }
        elsif($node->is_noun() && !$node->is_pronoun())
        {
            $iset->set('nountype', 'com');
        }
        $node->set_lemma($lemma);
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
        my $afun   = $deprel;
        if ( $afun =~ s/_M$// )
        {
            $node->set_is_member(1);
        }
        # combined afuns (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $afun =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $afun = 'Atr';
        }
        # Annotation error (one occurrence in PDT 3.0): Coord must not be leaf.
        if($afun eq 'Coord' && $node->is_leaf() && $node->parent()->is_root())
        {
            $afun = 'ExD';
        }
        $node->set_afun($afun);
    }
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real afun. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
}



#------------------------------------------------------------------------------
# Convert analytical functions to universal dependency relations.
#------------------------------------------------------------------------------
sub afun_to_udeprel
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        my $udep = 'dep:'.$afun;
        my $parent = $node->parent();
        # Predicate or ExD child of the root:
        # It is labeled root, regardless of whether the afun is Pred or ExD.
        ###!!! TODO: But beware of coordination!
        if($parent->is_root())
        {
            $udep = 'root';
        }
        # Subject: nsubj, nsubjpass, csubj, csubjpass
        elsif($afun eq 'Sb')
        {
            # Is the parent a passive verb?
            ###!!! This will not catch reflexive passives. TODO: Catch them.
            if($parent->is_passive())
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $udep = $node->is_verb() ? 'csubjpass' : 'nsubjpass';
            }
            else # Parent is not passive.
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $udep = $node->is_verb() ? 'csubj' : 'nsubj';
            }
        }
        # Object: dobj, iobj, ccomp, xcomp
        elsif($afun eq 'Obj')
        {
            ###!!! If a verb has two or more objects, we should select one direct object and the others will be indirect.
            ###!!! We would probably have to consider all valency frames to do that properly.
            ###!!! TODO: An approximation that we probably could do in the meantime is that
            ###!!! if there is one accusative and one or more non-accusatives, then the accusative is the direct object.
            # If this is an infinitive then it is an xcomp (controlled clausal complement).
            # If this is a verb form other than infinitive then it is a ccomp.
            ###!!! TODO: But if the infinitive is part of periphrastic future, then it is ccomp, not xcomp!
            $udep = $node->is_verb() ? ($node->is_infinitive() ? 'xcomp' : 'ccomp') : 'dobj';
        }
        # Adverbial modifier: advmod, nmod, advcl
        # Note: UD also distinguishes the relation neg. In Czech, most negation is done using bound morphemes.
        # Separate negative particles exist but they are either ExD (replacing elided negated "to be") or AuxZ ("ne poslední zvýšení cen").
        # Examples: ne, nikoli, nikoliv, ani?, vůbec?
        # I am not sure that we want to distinguish them from the other AuxZ using the neg relation.
        # AuxZ words are mostly adverbs, coordinating conjunctions and particles. Other parts of speech are extremely rare.
        elsif($afun eq 'Adv')
        {
            ###!!! TODO: Important question: Did we restructure prepositional phrases before entering this method?
            ###!!! Can an Adv depend on an AuxP or AuxC?
            $udep = $node->is_verb() ? 'advcl' : $node->is_noun() ? 'nmod' : 'advmod';
        }
        # Copula has been reattached under the nominal predicate, which was originally Pnom.
        # The Cop afun does not occur in PDT; it is a result of the reattachment.
        elsif($afun eq 'Cop')
        {
            $udep = 'cop';
        }
        # Attribute of a noun: amod, nummod, nmod, acl
        elsif($afun eq 'Atr')
        {
            # Cardinal number is nummod, ordinal number is amod. It should not be a problem because Interset should categorize ordinals as special types of adjectives.
            ###!!! TODO: personal names, foreign phrases and named entities
            $udep = $node->is_numeral() ? 'nummod' : $node->is_adjective() ? 'amod' : $node->is_verb() ? 'acl' : 'nmod';
        }
        # Verbal attribute is analyzed as secondary predication.
        ###!!! TODO: distinguish core arguments (xcomp) from non-core arguments and adjuncts (acl/advcl).
        elsif($afun =~ m/^AtvV?$/)
        {
            $udep = 'xcomp';
        }
        # Auxiliary verb "být" ("to be"): aux, auxpass
        elsif($afun eq 'AuxV')
        {
            $udep = $parent->is_passive() ? 'auxpass' : 'aux';
            # Side effect: We also want to modify Interset. The PDT tagset does not distinguish auxiliary verbs but UPOS does.
            $node->iset()->set('verbtype', 'aux');
        }
        # Reflexive pronoun "se", "si" with mandatorily reflexive verbs.
        elsif($afun eq 'AuxT')
        {
            $udep = 'mwe:reflex';
        }
        # Reflexive pronoun "se", "si" used for reflexive passive.
        elsif($afun eq 'AuxR')
        {
            $udep = 'auxpass:reflex';
        }
        # AuxZ: intensifier
        elsif($afun eq 'AuxZ')
        {
            $udep = 'advmod:auxz'; ###!!! TODO: A better name?
        }
        # AuxY: Additional conjunction in coordination ... it has been relabeled during processing of coordinations.
        # AuxY: "jako" attached to Atv ... case
        elsif($afun eq 'AuxY')
        {
            $udep = 'case';
        }
        # Apposition
        elsif($afun eq 'Apposition')
        {
            $udep = 'appos';
        }
        # Punctuation
        elsif($afun =~ m/^Aux[XGK]$/)
        {
            $udep = 'punct';
        }
        ###!!! TODO: ExD with chains of orphans should be stanfordized!
        elsif($afun eq 'ExD')
        {
            $udep = 'dep';
        }
        # Previous transformation of coordination to the Stanford style caused that afuns of some nodes
        # actually are already universal dependency relations.
        elsif($afun =~ m/^(conj|cc|punct|case|mark)$/)
        {
            $udep = $afun;
        }
        # We may want to dedicate a new node attribute to the universal dependency relation label.
        # At present, conll/deprel is good enough and afun cannot be used because its value range is fixed.
        $node->set_conll_deprel($udep);
        # Remove the value of afun. It does not make sense in the restructured tree.
        # In addition, empty afun will make the value of conll/deprel visible in Tred.
        $node->set_afun(undef);
    }
}



#------------------------------------------------------------------------------
# Restructures coordinations to the Stanford style. We cannot use the methods
# inherited from HarmonizePDT because they always produce Prague style.
#------------------------------------------------------------------------------
sub restructure_coordination_stanford
{
    my $self  = shift;
    my $root  = shift;
    my $debug = shift;
    # Wait with debugging until the problematic sentence:
    #my $debug = $self->sentence_contains($root, 'Spürst du das');
    log_info('DEBUG ON') if ($debug);
    #$self->shape_coordination_recursively_stanford( $root, $debug );
    #$self->shape_coordination_cloud_stanford($root);
    $self->shape_coordination_stanford($root);
}



#------------------------------------------------------------------------------
# Recursively search for coordinations and solve them immediately, i.e. don't
# collect all first. Use the Coordination object.
#------------------------------------------------------------------------------
sub shape_coordination_recursively_stanford
{
    my $self  = shift;
    my $root  = shift;
    my $debug = shift;
    my $coordination = new Treex::Core::Coordination;
    # We can use the inherited method detect_coordination(). It detects the
    # Prague style because it expects it in the input tree, but we also expect
    # this style after the initial harmonization to HamleDT/Prague.
    my @recursion = $self->detect_coordination($root, $coordination, $debug);
    if(scalar($coordination->get_conjuncts())>0)
    {
        log_info('COORDINATION FOUND') if ($debug);
        # We have found coordination! Solve it right away.
        $coordination->shape_stanford();
        # Call recursively on all descendants. (The exact recursive set depends on annotation style.
        # We got it from detect_coordination().)
        foreach my $node (@recursion)
        {
            $self->shape_coordination_recursively_stanford($node, $debug);
        }
    }
    # Call recursively on all children if no coordination detected now.
    else
    {
        foreach my $child ($root->children())
        {
            $self->shape_coordination_recursively_stanford($child, $debug);
        }
    }
}



#------------------------------------------------------------------------------
# Converts coordination from the Prague style to the Stanford style.
#------------------------------------------------------------------------------
sub shape_coordination_cloud_stanford
{
    my $self = shift;
    my $root = shift;
    # Convert the tree of nodes to tree of clouds, i.e. build the parallel structure.
    my $cloud = new Treex::Core::Cloud;
    # This method assumes that coordination is in the Prague style.
    $cloud->create_from_node($root);
    # Traverse the tree of clouds.
    $self->shape_coordination_cloud_stanford_recursive($cloud);
    $cloud->destroy_children();
}
sub shape_coordination_cloud_stanford_recursive
{
    my $self = shift;
    my $cloud = shift;
    # Recursively process children first, then process the current cloud.
    ###!!! Jenže to nefunguje. Když je dítětem koordinace a já ji přeskládám, tak ji najednou nereprezentuje spojka,
    ###!!! ale první člen. Ale Cloud o tom neví a nadřazená koordinace taky ne. Takže až budu převěšovat nadřazenou
    ###!!! koordinaci, ona chytne spojku a bude si myslet, že přesouvá vnořenou koordinaci, ale zatím pouze vytrhne
    ###!!! spojku z vnořené koordinace, ve které už mezitím spojka visela jako list.
    # Recursion that traverses the whole tree means that we go to both participants and modifiers.
    my @participants = $cloud->get_participants();
    my @modifiers = $cloud->get_shared_modifiers();
    foreach my $child (@participants, @modifiers)
    {
        $self->shape_coordination_cloud_stanford_recursive($child);
    }
    # Process the current cloud.
    if($cloud->is_coordination())
    {
        ###!!! Warning: The Cloud class assumes that coordination is always shaped in the Prague style.
        ###!!! We can restructure the coordination now but we cannot subsequently call $cloud->set_afun()
        ###!!! or other methods that will reshape the coordination in the Prague style.
        my $coordination = $cloud->_get_coordination();
        $coordination->shape_stanford();
    }
}



#------------------------------------------------------------------------------
# Converts coordination from the Prague style to the Stanford style.
#------------------------------------------------------------------------------
sub shape_coordination_stanford
{
    my $self = shift;
    my $node = shift;
    # Proceed bottom-up. First process children, then the current node.
    my @children = $node->children();
    foreach my $child (@children)
    {
        $self->shape_coordination_stanford($child);
    }
    # After processing my children, some of them may have ceased to be my children and some new children may have appeared.
    # This is the result of restructuring a child coordination.
    # Get the new list of children. In addition, we now require that the list is ordered (we have to identify the first conjunct).
    @children = $node->get_children({ordered => 1});
    # We have a coordination if the current node's afun is Coord.
    if($node->afun() eq 'Coord')
    {
        # If we are a nested coordination, remember it. We will have to set is_member for the new head.
        my $current_coord_is_member = 0;
        if($node->is_member())
        {
            $current_coord_is_member = 1;
            $node->set_is_member(0);
        }
        # Get conjuncts.
        my @conjuncts = grep {$_->is_member()} @children;
        my @dependents = grep {!$_->is_member()} @children;
        if(scalar(@conjuncts)==0)
        {
            log_warn('Coordination without conjuncts');
            # There must not be any node labeled Coord and having no is_member children.
            $node->set_afun('AuxY');
        }
        else
        {
            # Set the first conjunct as the new head.
            # Its afun should be already OK. It should not be a nested Coord because we processed the children first.
            my $head = shift(@conjuncts);
            $head->set_parent($node->parent());
            $head->set_is_member($current_coord_is_member);
            # Re-attach the current node and all its children to the new head.
            # Mark conjuncts using the UD relation conj.
            foreach my $conjunct (@conjuncts)
            {
                $conjunct->set_parent($head);
                $conjunct->set_afun('conj');
                $conjunct->set_conll_deprel('conj');
                # Clear the is_member flag for all conjuncts. It only made sense in the Prague style.
                $conjunct->set_is_member(0);
            }
            foreach my $dependent (@dependents, $node)
            {
                $dependent->set_parent($head);
                if($dependent->is_punctuation())
                {
                    $dependent->set_afun('punct');
                    $dependent->set_conll_deprel('punct');
                }
                elsif($dependent->afun() =~ m/^(Coord|AuxY)$/)
                {
                    $dependent->set_afun('cc');
                    $dependent->set_conll_deprel('cc');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Reattach prepositions as dependents of their noun phrases.
# Reattach subordinating conjunctions as dependents of their clauses.
# Assumption: Coordination has already been converted to Stanford style.
#------------------------------------------------------------------------------
sub push_prep_sub_down
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->afun() =~ m/^Aux[PC]$/)
        {
            # In the prototypical case, the node has just one child and it will swap positions with the child.
            ###!!! TODO: If the child is also Aux[PC], we should process the chain recursively.
            ###!!! TODO: First solve multi-word prepositions and all occurrences of leaf prepositions / subordinators.
            ###!!! TODO: Are there any prepositions with two or more arguments attached directly to them?
            ###!!! TODO: A preposition may have multiple children, one is its argument and the rest is Stanford coordination:
            ###!!!       ve městě a na vsi ... PrepArg(ve, městě), cc(ve, a), conj(ve, na), PrepArg(na, vsi)
            ###!!! TODO: On the other hand, if the argument of the preposition is coordination, the preposition should become a shared modifier of the coordination.
            ###!!! TODO: A preposition or subordinating conjunction may also have multiple children if there is punctuation.
            my @children = $node->get_children();
            my @punct_children = grep {$_->is_punctuation()} @children;
            my @non_punct_children = grep {!$_->is_punctuation()} @children;
            if(scalar(@non_punct_children)==1)
            {
                my $preposition = $node;
                my $noun = $non_punct_children[0];
                $noun->set_parent($preposition->parent());
                $preposition->set_parent($noun);
                foreach my $punct_child (@punct_children)
                {
                    $punct_child->set_parent($noun);
                }
                if($preposition->afun() eq 'AuxP')
                {
                    $preposition->set_afun('case');
                }
                else # AuxC
                {
                    $preposition->set_afun('mark');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Reattach copulas as dependents of their nominal predicates.
# Assumption: Coordination has already been converted to Stanford style.
#------------------------------------------------------------------------------
sub push_copulas_down
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->afun() eq 'Pnom')
        {
            my $pnom = $node;
            my $copula = $node->parent();
            my $grandparent = $copula->parent();
            if(defined($grandparent))
            {
                $pnom->set_parent($grandparent);
                $pnom->set_afun($copula->afun());
                # All other children of the copula will be reattached to the nominal predicate.
                # The copula will become a leaf.
                my @children = $copula->children();
                foreach my $child (@children)
                {
                    $child->set_parent($pnom);
                }
                $copula->set_parent($pnom);
                $copula->set_afun('Cop');
                $copula->set_conll_deprel('cop');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Reattach sentence-final punctuation to the main predicate.
# Assumption: Coordination has already been converted to Stanford style, thus
# any punctuation node attached directly to the root does not head coordination.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_predicate
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->children();
    my @pnodes = grep {$_->is_punctuation()} @nodes;
    my @npnodes = grep {!$_->is_punctuation()} @nodes;
    if(@npnodes)
    {
        my $predicate = $npnodes[-1];
        foreach my $pnode (@pnodes)
        {
            $pnode->set_parent($predicate);
            $pnode->set_conll_deprel('punct');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::Udep

Converts PDT (Prague Dependency Treebank) analytical trees to the Universal
Dependencies. This block is experimental. In the future, it may be split into
smaller blocks, moved elsewhere in the inheritance hierarchy or otherwise
rewritten. It is also possible (actually quite likely) that the current
Harmonize* blocks will be modified to directly produce Universal Dependencies,
which will become our new default central annotation style.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

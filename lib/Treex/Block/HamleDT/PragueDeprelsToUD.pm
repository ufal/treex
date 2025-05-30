package Treex::Block::HamleDT::PragueDeprelsToUD;
use utf8;
use open ':utf8';
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Converts Prague morphological tags and dependency relation labels to UD but
# does not change the structure yet. This means that the deprels are converted
# only partially: Some relation types will not exist once the tree is trans-
# formed, and some relations that do not exist now will be created.
#------------------------------------------------------------------------------
sub process_atree
{
    my ($self, $root) = @_;
    $self->exchange_tags($root);
    $self->fix_symbols($root);
    $self->fix_annotation_errors($root);
    $self->convert_deprels($root);
    $self->relabel_appos_name($root);
}



#------------------------------------------------------------------------------
# Replaces the tag from the original corpus by the corresponding Universal POS
# tag; saves the original tag in conll/pos instead. This would be done also in
# Write::CoNLLU. But even if we write Treex and view it in Tred, we want the UD
# tree to display the UPOS tags.
#------------------------------------------------------------------------------
sub exchange_tags
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $original_tag = $node->tag();
        $node->set_tag($node->iset()->get_upos());
        ###!!! Do not do this now! If we were converting via Prague, the $original_tag now contains a PDT-style tag.
        ###!!! On the other hand, already the Prague harmonization stored the really original tag in conll/pos.
        #$node->set_conll_pos($original_tag);
    }
}



#------------------------------------------------------------------------------
# Some treebanks do not distinguish symbols from punctuation. This method fixes
# this for a few listed symbols. Some other treebanks tag symbols as the words
# they substitute for (e.g. '%' is NOUN but it should be SYM).
#------------------------------------------------------------------------------
sub fix_symbols
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # '%' (percent), '$' (dollar), and '§' (paragraph) will be tagged SYM regardless their
        # original part of speech (probably PUNCT or NOUN). Note that we do not
        # require that the token consists solely of the symbol character.
        # Especially with '$' there are tokens like 'US$', 'CR$' etc. that
        # should be included.
        if($node->form() =~ m/[\$%§°]$/)
        {
            $node->iset()->set('pos', 'sym');
            # Unlike spelled-out nouns, symbols normally do not have morphological
            # features, although there may be language-specific deviations.
            $node->iset()->clear('case');
            $node->iset()->clear('style');
            # If the original dependency relation was AuxG, it should be changed but there is no way of knowing the correct relation.
            # The underlying words are nouns, hence they could be Sb, Obj, Adv, Atr, Apposition or even Pnom.
        }
        elsif($node->is_punctuation())
        {
            # Note that some characters cannot be decided in this simple way.
            # For example, '-' is either punctuation (hyphen) or symbol (minus)
            # but we cannot tell them apart automatically if we do not understand the sentence.
            if($node->form() =~ m/^[\+=]$/)
            {
                $node->iset()->set('pos', 'sym');
                if($node->deprel() eq 'AuxG')
                {
                    $node->set_deprel('AuxY');
                }
            }
            # Slash '/' can be punctuation or mathematical symbol.
            # It is difficult to tell automatically but we will make it a symbol if it is not leaf (and does not head coordination).
            elsif($node->form() eq '/' && !$node->is_leaf() && $node->deprel() !~ m/^(Coord|Apos)$/)
            {
                $node->iset()->set('pos', 'sym');
                if($node->deprel() eq 'AuxG')
                {
                    $node->set_deprel('AuxY');
                }
                my $parent = $node->parent();
                my @children = $node->children();
                foreach my $child (@children)
                {
                    $child->set_parent($parent);
                }
            }
        }
        # The letter 'x' sometimes substitutes the multiplication symbol '×'.
        elsif($node->form() eq 'x' && $node->is_conjunction())
        {
            $node->iset()->set('pos', 'sym');
            if($node->deprel() eq 'AuxG')
            {
                $node->set_deprel('AuxY');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Convert analytical functions to universal dependency relations.
# This new version (2015-03-25) is meant to act before any structural changes,
# even before coordination gets reshaped.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    # We will need to query the original Prague deprel (afun) of parent nodes in certain situations.
    # It will not be guaranteed that the parent deprel has not been converted by then. Therefore we will make a copy now.
    # Make sure that the copy is defined even if the parent is root.
    $root->wild()->{prague_deprel} = 'AuxS';
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel() // '';
        $node->wild()->{prague_deprel} = $deprel;
    }
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        $deprel = '' if(!defined($deprel));
        my $parent = $node->parent();
        # The top nodes (children of the root) must be labeled 'root'.
        # However, this will be solved elsewhere (and tree transformations may
        # result in a different node being attached to the root), so we will
        # now treat the labels as if nothing were attached to the root.
        # Punctuation is always 'punct' unless it depends directly on the root (which should happen only if there is just one node and the root).
        # We will temporarily extend the label if it heads coordination so that the coordination can later be reshaped properly.
        if($node->is_punctuation())
        {
            if($deprel eq 'Coord')
            {
                $deprel = 'coord';
            }
            else
            {
                $deprel = 'punct';
            }
        }
        # Coord marks the conjunction that heads a coordination.
        # (Punctuation heading coordination has been processed earlier.)
        # Coordinations will be later restructured and the conjunction will be attached as 'cc'.
        elsif($deprel eq 'Coord')
        {
            $deprel = 'coord';
        }
        # AuxP marks a preposition. There are two possibilities:
        # 1. It heads a prepositional phrase. The relation of the phrase to its parent is marked at the argument of the preposition.
        # 2. It is a leaf, attached to another preposition, forming a multi-word preposition. (In this case the word can be even a noun.)
        # Prepositional phrases will be later restructured. In the situation 1, the preposition will be attached to its argument as 'case'.
        # In the situation 2, the first word in the multi-word prepositon will become the head and all other parts will be attached to it as 'fixed'.
        elsif($deprel eq 'AuxP')
        {
            $deprel = 'case';
        }
        # AuxC marks a subordinating conjunction that heads a subordinate clause.
        # It will be later restructured and the conjunction will be attached to the subordinate predicate as 'mark'.
        elsif($deprel eq 'AuxC')
        {
            $deprel = 'mark';
        }
        # Predicate: If the node is not the main predicate of the sentence and it has the Pred deprel,
        # then it is probably the main predicate of a parenthetical expression.
        # Exception: predicates of coordinate main clauses. This must be solved after coordinations have been reshaped. ###!!! TODO
        elsif($deprel eq 'Pred')
        {
            $deprel = 'parataxis';
        }
        # Subject: nsubj, nsubj:pass, csubj, csubj:pass
        elsif($deprel eq 'Sb')
        {
            # Is the parent a passive verb?
            # Note that this will not catch all passives (e.g. reflexive passives).
            # Thus we will later check whether there is an aux:pass sibling.
            if($parent->iset()->is_passive())
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $deprel = $self->is_clausal_head($node) ? 'csubj:pass' : 'nsubj:pass';
            }
            else # Parent is not passive.
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $deprel = $self->is_clausal_head($node) ? 'csubj' : 'nsubj';
            }
        }
        # Object: obj, iobj, ccomp, xcomp
        elsif($deprel eq 'Obj')
        {
            # If a verb has two or more bare accusative objects, we should select
            # one for the 'obj' relation and the others will be 'iobj'. There
            # is only a handful of verbs that allow this (e.g., "učit někoho něco"
            # = to teach somebody something) in languages that have the dative
            # case (which is oblique). This will have to be resolved later when
            # the tree structure is converted. See Treex::Tool::PhraseBuilder::
            # PragueToUD::detect_indirect_object().
            if($self->is_clausal_head($node))
            {
                # If this is an infinitive then it is an xcomp (controlled clausal complement).
                # If this is a verb form other than infinitive then it is a ccomp.
                ###!!! TODO: But if the infinitive is part of periphrastic future, then it is ccomp, not xcomp!
                ###!!! TODO: If the infinitival clause starts with an interrogative/relative word, it may be ccomp: "věděl, co dělat" ("he knew what to do")
                # Indo-European bias: We expect the subordinator to precede the infinitive. Some Czech examples:
                # ccomp: věděl, co dělat (he knew what to do)
                # ccomp: co dělat, věděl (he knew what to do)
                # xcomp: toho, kdo nespolupracoval, museli umlčet (they had to silence those who did not cooperate)
                # xcomp: nevím, koho museli umlčet (I do not know whom they had to silence)
                # xcomp: umlčet toho, kdo nespolupracoval, museli (they had to silence those who did not cooperate)
                # xcomp: neměla co příst / kam jít / o čem vyprávět (she did not have what to spin / where to go / what to tell)
                # It seems impossible to recognize ccomp infinitives without a
                # language-specific database of the parent verbs. Thus we
                # should fix it in a language-specific FixUD module.
                my $xcomp = $node->is_infinitive();
                #if($xcomp && $node->ord() > $parent->ord())
                #{
                #    my @subordinators = grep {$_->ord() > $parent->ord() && ($_->is_subordinator() || $_->is_relative() || $_->is_interrogative)} ($node->get_descendants({'preceding_only' => 1}));
                #    $xcomp = 0 if(scalar(@subordinators) > 0);
                #}
                $deprel = $xcomp ? 'xcomp' : 'ccomp';
            }
            else # nominal object
            {
                # Specific to case-marking Indo-European languages:
                # Non-accusative objects (including prepositional objects) are
                # considered oblique, i.e., they are not 'obj'. To preserve the
                # information that the original annotation considers them
                # arguments (objects), they get a special subtype, 'obl:arg'.
                # We convert deprels before the structure is changed, so we can
                # ask whether the direct parent node is a preposition.
                ###!!! This will not work properly if there is coordination!
                ###!!! We should recheck the structure when it has been transformed
                ###!!! to UD, and see whether there are any "case" dependents.
                $deprel = $parent->is_adposition() ? 'obl:arg' : 'obj';
            }
        }
        # Nominal predicate attached to a copula verb.
        elsif($deprel eq 'Pnom')
        {
            # We will later transform the structure so that copula depends on the nominal predicate.
            # The 'pnom' label will disappear and the inverted relation will be labeled 'cop'.
            # We cannot do this if the predicate is a subordinate clause ("my opinion is that we should not go there"). Then a verb would have two subjects.
            if($node->is_verb() && !$node->is_participle())
            {
                $deprel = 'ccomp';
            }
            # The symbol "=" is tagged SYM and substitutes a verb ("equals to"). This verb is not considered copula (only "to be" is copula).
            # Hence we will re-classify the relation as object.
            elsif(!$parent->is_root() && $parent->form() eq '=')
            {
                $deprel = 'obj';
            }
            else
            {
                $deprel = 'pnom';
            }
        }
        # Nominal predicate attached to the subject if there is no copula (Lithuanian ALKSNIS).
        # It could also depend on the artificial root node if there is no verb in the sentence.
        elsif($deprel eq 'PredN')
        {
            if($parent->is_root() || $parent->wild()->{prague_deprel} =~ m/^Coord/i && $parent->parent()->is_root())
            {
                # One of them will later be picked as the 'root' child.
                # We want the others to become its conjuncts.
                $deprel = 'conj';
            }
            else # under subject without copula
            {
                # It will be restructured later, then the deprel will also change.
                $deprel = 'predn';
            }
        }
        # Adverbial modifier: advmod, obl, advcl
        elsif($deprel eq 'Adv')
        {
            ###!!! Manual disambiguation is needed here. For example, in Czech:
            ###!!! Úroda byla v tomto roce o mnoho lepší než loni.
            ###!!! There should be obl(lepší, roce) but nmod(lepší, mnoho).
            # Adposition leads to 'obl' because of preposition stranding in languages like English (i.e., it is promoted in ellipsis).
            # Advcl: is_clausal_head() or subordinating conjunction (stranded in incomplete clauses).
            $deprel = $self->is_clausal_head($node) || $node->is_subordinator() ? 'advcl' : ($node->is_noun() || $node->is_adjective() || $node->is_numeral() || $node->is_adposition() || $node->iset()->pos() eq '') ? 'obl' : 'advmod';
        }
        # Attribute of a noun: amod, nummod, nmod, acl
        elsif($deprel eq 'Atr')
        {
            # Czech-specific: Postponed genitive modifiers should usually be
            # 'nmod' even if they are headed by an adjective or a determiner
            # ("svědomí každého z nich"). However, there are counterexamples.
            # Agreeing adjectives can follow the modified noun instead of
            # preceding it, although it is rarer; if the whole nominal is in
            # genitive, the adjective will be in genitive, too, but it should
            # be still 'amod' and not 'nmod' ("molekula kyseliny uhličité").
            if($parent->ord() < $node->ord() && $node->iset()->is_genitive() && !$parent->iset()->is_genitive())
            {
                $deprel = 'nmod';
            }
            # Cardinal number is nummod, ordinal number is amod. It should not be a problem because Interset should categorize ordinals as special types of adjectives.
            # But we cannot use the is_numeral() method because it returns true if pos=num or if numtype is not empty.
            # We also want to exclude pronominal numerals (kolik, tolik, mnoho, málo). These should be det.
            elsif($node->iset()->pos() eq 'num')
            {
                if($node->iset()->prontype() eq '')
                {
                    # If we later push the numeral down, we will label it nummod:gov.
                    $deprel = 'nummod';
                }
                else
                {
                    # If we later push the quantifier down, we will label it det:numgov.
                    $deprel = 'det:nummod';
                }
            }
            # Names and surnames should be connected using flat or flat:name, the first node is the head.
            # The flat structure extends to titles and occupations such as "Mr.", "professor", "president",
            # provided that they agree with the name in gender, number and case, and they precede the name (at least in Czech).
            elsif($parent->iset()->nametype() =~ m/(giv|sur|prs)/ &&
                  ($node->iset()->nametype() =~ m/(giv|sur|prs)/ ||
                   $node->ord() < $parent->ord() &&
                   $node->is_noun() && !$node->is_pronominal() &&
                   $node->iset()->gender() eq $parent->iset()->gender() &&
                   $node->iset()->animacy() eq $parent->iset()->animacy() &&
                   $node->iset()->number() eq $parent->iset()->number() &&
                   $node->iset()->case() eq $parent->iset()->case()))
            {
                $deprel = 'flat';
            }
            elsif($node->is_foreign() && $parent->is_foreign() ||
                  $node->is_foreign() && $node->is_adposition() && $parent->is_proper_noun())
                  ###!!! van Gogh, de Gaulle in Czech text; but it means we will have to reverse the relation left-to-right!
                  ###!!! Another solution would be to label the relation "case". But foreign prepositions do not have this function in Czech.
            {
                # Nathan Schneider wanted the UD validator to issue a warning if
                # 'flat:foreign' is used and the two nodes connected are not just
                # X Foreign=Yes with no other features. We cannot guarantee this
                # in PDT (for example, there is foreign journal name "New England
                # J. of Med.", where "J" is tagged as a domestic abbreviated NOUN,
                # while the other words are foreign and tagged X). Therefore we
                # will not distinguish flat:foreign from flat.
                $deprel = 'flat';
            }
            elsif($node->is_determiner() && $self->agree($node, $parent, 'case'))
            {
                $deprel = 'det';
            }
            # Passive participles in Czech are tagged as adjectives (both the short form
            # "udělán", which is used only predicatively, and the long form "udělaný",
            # which can be used attributively as a normal adjective). When they head
            # a clause, they should be acl (or acl:relcl) instead of amod. Ideally
            # we should look at their children (is there nsubj, aux, cop?) but we
            # cannot do it now when some deprels may still wait for conversion. Since
            # it is language-specific, it should be resolved later in CS::FixUD.
            # We cannot require case agreement for adjectives. Not only because
            # it is specific to Slavic languages, but also because occasional
            # errors in case annotation would lead to much more serious errors
            # in syntactic annotation.
            elsif($node->is_adjective())
            {
                $deprel = 'amod';
            }
            elsif($node->is_adverb())
            {
                $deprel = 'advmod';
            }
            elsif($self->is_clausal_head($node))
            {
                $deprel = 'acl';
            }
            else
            {
                $deprel = 'nmod';
            }
        }
        # App is used in the Lithuanian ALKSNIS 2.2 treebank and we keep it in the common Prague style even though
        # other treebanks do not use it, because the distinction is important when further converting to UD.
        # App means "appendix" / "priedėlis". Title or occupation is attached to the following name as App;
        # their morphological case is usually identical. App is similar to Atr, but in UD it should be 'flat', not 'nmod'.
        elsif($deprel eq 'App')
        {
            $deprel = 'flat';
        }
        # AuxA is not an official deprel used in HamleDT 2.0. Nevertheless it has been introduced in some (not all)
        # languages by people who want to use the resulting data in TectoMT. It marks articles attached to nouns.
        elsif($deprel eq 'AuxA')
        {
            $deprel = 'det';
        }
        # Verbal attribute is analyzed as secondary predication.
        ###!!! TODO: distinguish core arguments (xcomp) from non-core arguments and adjuncts (acl/advcl).
        elsif($deprel =~ m/^AtvV?$/)
        {
            $deprel = 'xcomp';
        }
        # Auxiliary verb "být" ("to be"): aux, aux:pass
        elsif($deprel eq 'AuxV')
        {
            # The Czech conditional auxiliary "by" is not aux:pass even if attached to a passive verb.
            $deprel = $parent->iset()->is_passive() && !$node->is_conditional() ? 'aux:pass' : 'aux';
            # Side effect: We also want to modify Interset. The PDT tagset does not distinguish auxiliary verbs but UPOS does.
            $node->iset()->set('verbtype', 'aux');
        }
        # Reflexive pronoun "se", "si" with inherently reflexive verbs.
        # Unfortunately, previous harmonization to the Prague style abused the AuxT label to also cover Germanic verbal particles and other compound-like stuff with verbs.
        # We have to test for reflexivity if we want to output expl:pv!
        elsif($deprel eq 'AuxT')
        {
            # This appears in Slavic languages, although in theory it could be used in some Romance and Germanic languages as well.
            # It actually also appears in Dutch (but we mixed it with verbal particles there).
            # Most Dutch pronouns used with this label are tagged as reflexive but a few are not.
            if($node->is_reflexive() || $node->is_pronoun())
            {
                $deprel = 'expl:pv';
            }
            # The Tamil deprel CC (compound) has also been converted to AuxT. 11 out of 12 occurrences are tagged as verbs.
            elsif($node->is_verb())
            {
                $deprel = 'compound';
            }
            # Germanic verbal particles can be tagged as various parts of speech, including adpositions. Hence we cannot distinguish them from
            # preposition between finite verb and infinitive, which appears in Portuguese. Examples: continua a manter; deixa de ser
            # en: 1181 PART, 28 ADP, 28 ADV, 3 ADJ; 27 different lemmas: 418 up, 261 out, 141 off...
            # de: 4002 PART; 138 different lemmas: 528 an, 423 aus, 350 ab...
            # nl: 1097 ADV, 460 PRON, 397 X, 176 ADJ, 157 NOUN, 99 ADP, 42 VERB, 9 SCONJ; 368 different lemmas: 402 zich, 178 uit, 167 op, 112 aan...
            # pt: 587 ADP, 53 SCONJ, 1 ADV; 5 different lemmas: 432 a, 114 de, 56 que, 38 por, 1 para
            else
            {
                $deprel = 'compound:prt';
            }
        }
        # Reflexive pronoun "se", "si" used for reflexive passive.
        elsif($deprel eq 'AuxR')
        {
            $deprel = 'expl:pass';
        }
        # AuxZ: intensifier or negation
        elsif($deprel eq 'AuxZ')
        {
            # In the Lithuanian treebank, some interjections are attached as AuxZ.
            # Interjections should be discourse in UD.
            if($node->is_interjection())
            {
                $deprel = 'discourse';
            }
            # Also in Lithuanian Alksnis, numbers of paragraphs are attached as AuxZ.
            elsif($node->is_numeral())
            {
                $deprel = 'dep';
            }
            # In PDT-C 2.0, "semantico-pragmatic expressions" such as "víš", "prosím tě",
            # are attached as AuxZ to the nearest mainstream clause. They should also
            # have is_parenthesis_root set. However, not all of them have is_parenthesis_root
            # (sometimes "prosím tě" is AuxZ but not parenthesis), and on the other
            # hand, is_parenthesis_root + AuxZ includes some non-clausal insertions
            # such as "také"; those should probably not end up as 'parataxis', while
            # verbs definitely cannot be 'advmod:emph'. So let's now just ask whether
            # we are looking at a verb.
            elsif($node->is_verb())
            {
                $deprel = 'parataxis';
            }
            # Some coordinating conjunctions in PDT-C 2.0 are also attached as AuxZ.
            ###!!! On the other hand, the other Prague-style treebanks (and older
            ###!!! versions of PDT itself) used AuxZ with the coordinator "i" when
            ###!!! it was used as a rhematizer ("mají význam i tím, že...").
            ###!!! Adding this branch means that we will lose them. Trying if it
            ###!!! helps to ignore the lemma "i" (but that is language-specific
            ###!!! and this block is supposed to be language-agnostic).
            elsif($node->is_coordinator() && $node->lemma() !~ m/^(ani|i)$/)
            {
                $deprel = 'cc';
            }
            # AuxZ is an emphasizing word (“especially on Monday”).
            # It also occurs with numbers (“jen čtyři firmy”, “jen několik procent”).
            # The word "jen" ("only") is not necessarily a restriction. It rather emphasizes that the number is a restriction.
            # On the tectogrammatical layer these words often get the functor RHEM (rhematizer / rematizátor = něco, co vytváří réma, fokus).
            # But this is not a 1-1 mapping.
            # https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/t-layer/html/ch10s06.html
            # https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/t-layer/html/ch07s07s05.html
            # Most frequent lemmas with AuxZ: i (4775 výskytů), jen, až, pouze, ani, už, již, ještě, také, především (689 výskytů)
            # Most frequent t-lemmas with RHEM: #Neg (7589 výskytů), i, jen, také, už, již, ani, až, pouze, například (500 výskytů)
            else
            {
                $deprel = 'advmod:emph';
            }
        }
        # Neg: used in Prague-style harmonization of some treebanks (e.g. Romanian) for negation (elsewhere it may be AuxZ or Adv).
        elsif($deprel eq 'Neg')
        {
            # There was a separate 'neg' relation in UD v1 but it was removed in UD v2.
            $deprel = 'advmod';
        }
        # The AuxY deprel is used in various situations, see below.
        elsif($deprel eq 'AuxY')
        {
            # An AuxY depending on an AuxC may signal a multiword subordinator, which could be converted to mark and later to fixed.
            # However, some combinations are not fixed expressions. This could be decided using language-specific lists; another clue
            # is that if the words are not adjacent, they probably do not form a compound subordinator.
            ###!!! See also HamleDT::CS::HarmonizePDTC::prevent_compound_subordinators();
            # When it is attached to a subordinating conjunction (AuxC), the two form a multi-word subordinator.
            # Index Thomisticus examples: ita quod (so that), etiam si (even if), quod quod (what is that), ac si (as if), et si (although)
            ###!!! But not always! E.g., we had an apposition "jako X, čili jako Y", it was hamledtized as a hypotactic structure, then "čili" ended up attached as AuxY to "jako", but they do not form a fixed compound subordinator!
            ###!!! Also not for double "že": "Myslí si, že když to máme za humny, že na to je dost času."
            if($parent->wild()->{prague_deprel} eq 'AuxC' && lc($node->form()) ne 'čili' && $node->form() !~ m/^(čili|že)$/i) ###!!! raději bych měl testovat formu rodiče i dítěte, abych zase nevyhodil něco, co vyhodit nechci!
            {
                # The phrase builder will later transform it to MWE.
                $deprel = 'mark';
            }
            # When it is attached to a complement (Atv, AtvV), it is usually an equivalent of the subordinating conjunction "as" and it should be 'mark'.
            # Czech: "jako" ("as"); sometimes it is attached even to Obj (of verbal adjectives). It should never get the 'cc' deprel, so we will mention it explicitly.
            # Index Thomisticus examples: ut (as), sicut (as), quasi (as), tanquam (like), utpote (as) etc.
            elsif($parent->wild()->{prague_deprel} =~ m/^AtvV?$/ ||
                  lc($node->form()) =~ m/^(ut|sicut|quasi|tanquam|utpote)$/)
                  ###!!!lc($node->form()) =~ m/^(jako|ut|sicut|quasi|tanquam|utpote)$/)
            {
                ###!!! 'jako' in this context may have worked well until PDT-C 1.0 but not now. I had the following comments that explain it for a while in BasePhraseBuilder.
                # Originally: AuxP attached to AuxP (or AuxC to AuxC, or even AuxC to AuxP or AuxP to AuxC) means a multi-word preposition (conjunction).
                # However (PDT-C 2.0, 2025-03): "stejně jako k tomu" --> "jako" was originally apposition head, then it got converted to AuxY, but during conversion to UD AuxY first becomes mark,
                # then it is unrecognizable from AuxC and it gets caught here.
                # Therefore, we tentatively try 'auxp' instead of 'auxpc' and see whether it harms other positions.
                ###!!! One of the problems is that in "stejně jako k tomu", "jako" is attached directly to the preposition "k" and not to its argument "tomu".
                ###!!! Perhaps we should add to the scenario a new block that will make sure that if AuxP has other children than its single argument, these children are only AuxP, AuxC, or punctuation.
                $deprel = 'mark';
            }
            # AuxY may be a preposition attached to an adverb; unlike normal AuxP prepositions, this one is not the head.
            # Index Thomisticus: ad invicem (each other); "invicem" is adverb that could be roughly translated as "mutually".
            elsif($node->is_adposition())
            {
                if($node->form() eq 'na' && $node->parent()->form() eq 'na') # simple repetition: To je město na na severu Čech.
                {
                    $deprel = 'reparandum';
                }
                else
                {
                    $deprel = 'case';
                }
            }
            # When it is attached to a verb, it is a sentence adverbial, disjunct or connector.
            # Index Thomisticus examples: igitur (therefore), enim (indeed), unde (whence), sic (so, thus), ergo (therefore).
            elsif($parent->is_verb() && !$node->is_coordinator())
            {
                if($node->is_verb())
                {
                    $deprel = 'compound';
                }
                else
                {
                    $deprel = 'advmod';
                }
            }
            # New in PDT-C 2.0 (see also https://github.com/UniversalDependencies/UD_Czech-PDT/issues/15):
            # Numeric part of "5 x", attached to the "krát" part.
            elsif($node->is_numeral())
            {
                $deprel = 'compound';
            }
            # Non-head conjunction in coordination is probably the most common usage.
            # Index Thomisticus examples: et (and), enim (indeed), vel (or), igitur (therefore), neque (neither).
            else
            {
                $deprel = 'cc';
            }
        }
        # AuxO: redundant "to" or "si" ("co to znamená pátý postulát dokázat").
        elsif($deprel eq 'AuxO')
        {
            $deprel = 'discourse';
        }
        # Apposition
        elsif($deprel eq 'Apposition')
        {
            $deprel = 'appos';
        }
        # Punctuation
        ###!!! Since we now label all punctuation (decided by Interset) as punct,
        ###!!! here we only get non-punctuation labeled (by mistake?) AuxG, AuxX or AuxK. What to do with this???
        elsif($deprel eq 'AuxG')
        {
            # AuxG is intended for graphical symbols other than comma and the sentence-terminating punctuation.
            # It is mostly assigned to punctuation but sometimes to symbols (% $ + x) or even alphanumeric tokens (1 2 3).
            # The 'punct' deprel should be used only for punctuation.
            # We do not really know what the label should be in this case.
            # For mathematical operators (+ - x /) it should be probably 'cc'.
            # (But we cannot distinguish minus from hyphen, so with '-' we will not get here. Same for '/'.)
            # For % and $ it could be any label used with noun phrases.
            if($node->form() =~ m/^[+x]$/)
            {
                $deprel = 'cc';
            }
            else
            {
                $deprel = 'nmod'; ###!!! or nsubj or obj or whatever
                # One use case is item labels in ordered lists ("a)", "b)" etc.)
                # They should be attached to the head of the list item. The
                # problem is if the head is AuxC or AuxP: during later structural
                # conversion, the nmod node may be picked as the actual argument
                # of the preposition; it would not happen if it stayed punctuation.
                # Observed in Czech CLTT. It may look differently in other treebanks
                # (for example, "a)" may be treated as two tokens there).
            }
        }
        elsif($deprel =~ m/^Aux[XK]$/)
        {
            # AuxX is reserved for commas.
            # AuxK is used for sentence-terminating punctuation, usually a period, an exclamation mark or a question mark.
            log_warn("Node '".$node->form()."' has deprel '$deprel' but it is not punctuation.");
            $deprel = 'punct';
        }
        ###!!! TODO: ExD with chains of orphans should be stanfordized!
        elsif($deprel eq 'ExD')
        {
            # Some ExD are vocatives. (In older treebanks; in PDT-C 2.0, there is a new relation Vocat.)
            if($node->iset()->case() eq 'voc')
            {
                $deprel = 'vocative';
            }
            # Some ExD are properties or quantities compared to.
            ###!!! This is specific to Czech!
            elsif(defined($parent->lemma()) && $parent->lemma() =~ m/^(jako|než)$/)
            {
                $deprel = 'advcl';
            }
            else
            {
                $deprel = 'dep';
            }
        }
        elsif($deprel eq 'Vocat')
        {
            $deprel = 'vocative';
        }
        # A noun phrase that is added at the level of a separate clause, weakly
        # linked as an addition to something said in the sentence. It could be
        # in parentheses, or after a comma (such as "tel." + number after a name).
        # Since PDT-C 2.0 it has its own relation Denom, which should become
        # parataxis in UD.
        elsif($deprel eq 'Denom')
        {
            $deprel = 'parataxis';
        }
        # An interjection that is inserted at the clausal level. Since PDT-C 2.0
        # it has its own relation Partl, which should become discourse in UD.
        elsif($deprel eq 'Partl')
        {
            $deprel = 'discourse';
        }
        # Set up a fallback so that $deprel is always defined.
        else
        {
            $deprel = 'dep:'.lc($deprel);
        }
        # Save the universal dependency relation label with the node.
        $node->set_deprel($deprel);
    }
    # Now that all deprels have been converted we do not need the copies of the original deprels any more. Delete them.
    delete($root->wild()->{prague_deprel});
    foreach my $node (@nodes)
    {
        delete($node->wild()->{prague_deprel});
    }
}



#------------------------------------------------------------------------------
# Tells for a node whether its subtree is likely a clause or not. This is
# necessary to figure out the UD type of the incoming relation (e.g., a nominal
# subject is attached as 'nsubj', a clausal subject as 'csubj'). Since this
# method will be called during conversion of relation labels, we cannot rely on
# them: neither that they are in the Prague style, nor the UD style. The tree
# structure is still in the Prague style. Interset is available.
#------------------------------------------------------------------------------
sub is_clausal_head
{
    my $self = shift;
    my $node = shift;
    # If the current node is a verb, it heads a clause.
    # Note that even nominal predicates are headed by the copula verb in the Prague style.
    return 1 if($node->is_verb());
    # Passive participles in Slavic languages have been retagged as adjectives.
    # They have the auxiliary verb as a child (but the lemma of the verb is
    # language-specific and the relation type is either AuxV or aux:pass,
    # depending on whether that node has already been converted).
    if($node->is_participle() && $node->iset()->is_passive())
    {
        my @children = $node->children();
        if(any {$_->is_verb()} (@children))
        {
            return 1;
        }
    }
    return 0;
}



#------------------------------------------------------------------------------
# In the Croatian SETimes corpus, given name of a person depends on the family
# name, and the relation is labeled as apposition. Change the label to 'flat'.
# This should be done before we start structural transformations.
#------------------------------------------------------------------------------
sub relabel_appos_name
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if(defined($deprel) && $deprel eq 'appos')
        {
            my $parent = $node->parent();
            next if($parent->is_root());
            if($node->is_proper_noun() && $parent->is_proper_noun() && $self->agree($node, $parent, 'case'))
            {
                $node->set_deprel('flat');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Checks agreement between two nodes in one Interset feature. An empty value
# agrees with everything (because it can be interpreted as "any value").
#------------------------------------------------------------------------------
sub agree
{
    my $self = shift;
    my $node1 = shift;
    my $node2 = shift;
    my $feature = shift;
    my $i1 = $node1->iset();
    my $i2 = $node2->iset();
    return 1 if($i1->get($feature) eq '' || $i2->get($feature) eq '');
    return 1 if($i1->get_joined($feature) eq $i2->get_joined($feature));
    # If one or both the nodes have multiple values of the feature and their
    # intersection is not empty, take it as agreement.
    my @v1 = $i1->get_list($feature);
    foreach my $v1 (@v1)
    {
        return 1 if($i2->contains($feature, $v1));
    }
    return 0;
}



#------------------------------------------------------------------------------
# Fixes annotation errors. In the Czech PDT, abbreviations are sometimes
# confused with prepositions. For example, "s.r.o." ("společnost s ručením
# omezeným" = "Ltd.") is tokenized as "s . r . o ." and both "s" and "o" could
# also be prepositions. Sometimes it happens that morphological analysis is
# correct (abbreviated NOUN resp. ADJ) but syntactic analysis is not (the
# incoming edge is labeled AuxP).
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        my $pos  = $node->iset()->pos();
        my $deprel = $node->deprel();
        if($form =~ m/^[so]$/i && !$node->is_adposition() && $deprel eq 'AuxP')
        {
            # We do not know what the correct deprel would be. There is a chance it would be Apposition or Atr but it is not guaranteed.
            # On the other hand, any of the two, even if incorrect, is much better than AuxP, which would trigger various transformations,
            # inappropriate in this context.
            $node->set_deprel('Atr');
        }
        # Fix unknown tags of punctuation. If the part of speech is unknown and the form consists only of punctuation characters,
        # set the part of speech to PUNCT. This occurs in the Ancient Greek Dependency Treebank.
        elsif($pos eq '' && $form =~ m/^\pP+$/)
        {
            $node->iset()->set_pos('punc');
        }
        # Czech "jakmile" is always tagged SCONJ (although one could also argue that it is a relative adverb of time).
        # In 55 cases it is attached as AuxC and in 1 case as Adv; but this 1 case is not different, it is an error.
        # Changing Adv to AuxC would normally also involve moving the conjunction between the subordinate predicate and
        # its parent, but we do not need to do that because our target style is UD and there both AuxC (mark) and Adv (advmod)
        # will be attached as children of the subordinate predicate.
        elsif(lc($form) eq 'jakmile' && $pos eq 'conj' && $deprel eq 'Adv')
        {
            $node->set_deprel('AuxC');
        }
        # In the Czech PDT, there is one occurrence of English "Devil ' s Hole", with the dependency AuxT(Devil, s).
        # Since "s" is not a reflexive pronoun, the convertor would convert the AuxT to compound:prt, which is not allowed in Czech.
        # Make it Atr instead. It will be converted to foreign.
        elsif($form eq 's' && $node->deprel() eq 'AuxT' && $node->parent()->form() eq 'Devil')
        {
            $node->set_deprel('Atr');
        }
        # PDT-C 2.0 train tamw ln94211_30 # 13
        # Pokud, ale to je ošklivá představa!, pokud v tom nejsou staré dobré zvyky.
        # We have AuxY(pokud-10, Pokud-1). It should be probably reparandum.
        elsif($form eq 'Pokud' && $deprel eq 'AuxY' && $node->parent()->form() eq 'pokud')
        {
            $node->set_deprel('reparandum');
        }
        # PDT-C 2.0 train tamw mf920922_090 # 5
        elsif($form eq 'au' && $node->parent()->form() eq 'pair')
        {
            # This will result in 'amod' but we may actually prefer 'compound'.
            $node->set_deprel('Atr');
        }
        # PDT-C 2.0 train amw vesm9211_001 # 27
        elsif($form eq 'neboli' && $node->parent()->form() eq 'jako')
        {
            my @takove = grep {$_->form() eq 'takové'} ($node->get_siblings());
            if(scalar(@takove) > 0)
            {
                $node->set_parent($takove[0]);
            }
        }
        # In AnCora (ca+es), the MWE "10_per_cent" will have the lemma "10_%", which is a mismatch in number of elements.
        elsif($form =~ m/_(per_cent|por_ciento)$/i && $lemma =~ m/_%$/)
        {
            $lemma = lc($form);
            $node->set_lemma($lemma);
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::PragueDeprelsToUD

Converts morphological tags and dependency relation labels from Prague to
Universal Dependencies. Does not touch the tree structure, that is left for
subsequent blocks. That also means that the deprel conversion is only
approximate. Some relation types will cease to exist when the tree is
transformed, and some types that do not exist now will be created.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2016, 2025 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

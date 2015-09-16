package Treex::Block::HamleDT::Udep;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Phrase::Builder;
extends 'Treex::Core::Block';

has 'last_file_stem' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'   => ( is => 'rw', isa => 'Int', default => 0 );



#------------------------------------------------------------------------------
# Reads a Prague-style tree and transforms it to Universal Dependencies.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    # Add the name of the input file and the number of the sentence inside
    # the file as a comment that will be written in the CoNLL-U format.
    # (In any case, Write::CoNLLU will print the sentence id. But this additional
    # information is also very useful for debugging, as it ensures a user can find the sentence in Tred.)
    my $bundle = $zone->get_bundle();
    my $file_stem = $bundle->get_document()->file_stem();
    if($file_stem eq $self->last_file_stem())
    {
        $self->set_sent_in_file($self->sent_in_file() + 1);
    }
    else
    {
        $self->set_last_file_stem($file_stem);
        $self->set_sent_in_file(1);
    }
    my $sent_in_file = $self->sent_in_file();
    my $comment = "orig_file_sentence $file_stem\#$sent_in_file";
    my @comments;
    if(defined($bundle->wild()->{comment}))
    {
        @comments = split(/\n/, $bundle->wild()->{comment});
    }
    unless(any {$_ eq $comment} (@comments))
    {
        push(@comments, $comment);
        $bundle->wild()->{comment} = join("\n", @comments);
    }
    # Now the harmonization proper.
    my $root = $zone->get_atree();
    $self->exchange_tags($root);
    $self->fix_symbols($root);
    $self->fix_annotation_errors($root);
    $self->afun_to_udeprel($root);
    ###!!!
    # Backup the tree before applying any structural transformations.
    # This is a temporary debugging measure: we want to make sure that the new implementation does not introduce errors.
    my $before0 = $root->get_subtree_dependency_string();
    my $before0brat = $root->get_subtree_dependency_string(1);
    my $src_language = $root->language();
    my $src_selector = $root->selector();
    my $tgt_language = $src_language;
    my $tgt_selector = 'backup';
    my $tgt_zone = $bundle->get_or_create_zone($tgt_language, $tgt_selector);
    my $tgt_root = $tgt_zone->create_atree();
    $root->copy_atree($tgt_root);
    my $before1 = $tgt_root->get_subtree_dependency_string();
    my $before1brat = $tgt_root->get_subtree_dependency_string(1);
    if($before0 ne $before1)
    {
        log_info("BEFORE 0: $before0");
        log_info("BEFORE 1: $before1");
        log_fatal("Copy of tree does not match the original.");
    }
    # Back to the harmonization.
    $self->shape_coordination_stanford($root);
    $self->restructure_compound_prepositions($root);
    $self->push_prep_sub_down($root);
    $self->change_case_to_mark_under_verb($root);
    ###!!! New implementation: transform prepositions and coordination via phrases.
    my $builder = new Treex::Core::Phrase::Builder ('prep_is_head' => 0, 'coordination_head_rule' => 'first_conjunct');
    my $phrase = $builder->build($tgt_root);
    $phrase->project_dependencies();
    ###!!! Compare the trees before and after the transformation.
    my $after0 = $root->get_subtree_dependency_string();
    my $after1 = $tgt_root->get_subtree_dependency_string();
    my $after0brat = $root->get_subtree_dependency_string(1);
    my $after1brat = $tgt_root->get_subtree_dependency_string(1);
    if($after0 ne $after1)
    {
        log_info("BEFORE:  $before1");
        log_info("AFTER 0: $after0");
        log_info("AFTER 1: $after1");
        # The tree code for Brat may span too many lines and we will not see it if it is printed directly to the terminal.
        # Warning! This code attempts to create or modify a file in the current working folder on the disk!
        if(open(BAD, ">bad_trees.brat"))
        {
            print BAD ("BEFORE:\n\n$before1brat\nAFTER 0:\n\n$after0brat\nAFTER 1:\n\n$after1brat\n");
            close(BAD);
        }
        log_fatal("Regression test failed.");
    }
    # Some of the top colons are analyzed as copulas. Do this before the copula processing reshapes the scene.
    $self->colon_pred_to_apposition($root);
    $self->push_copulas_down($root);
    $self->attach_final_punctuation_to_predicate($root);
    $self->classify_numerals($root);
    $self->restructure_compound_numerals($root);
    $self->push_numerals_down($root);
    $self->fix_determiners($root);
    $self->relabel_top_nodes($root);
    $self->relabel_subordinate_clauses($root);
    $self->relabel_appos_name($root);
    # Sanity checks.
    $self->check_determiners($root);
    ###!!! The EasyTreex extension of Tred currently does not display values of the deprel attribute.
    ###!!! Copy them to conll/deprel (which is displayed) until we make Tred know deprel.
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $upos = $node->iset()->upos();
        my $ufeat = join('|', $node->iset()->get_ufeatures());
        $node->set_tag($upos);
        $node->set_conll_cpos($upos);
        $node->set_conll_feat($ufeat);
        $node->set_conll_deprel($node->deprel());
        $node->set_afun(undef); # just in case... (should be done already)
    }
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
# this for a few listed symbols.
#------------------------------------------------------------------------------
sub fix_symbols
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->is_punctuation())
        {
            # Note that some characters cannot be decided in this simple way.
            # For example, '-' is either punctuation (hyphen) or symbol (minus)
            # but we cannot tell them apart automatically if we do not understand the sentence.
            if($node->form() =~ m/^[\$%\+=]$/)
            {
                $node->iset()->set('pos', 'sym');
                if($node->afun() eq 'AuxG')
                {
                    $node->set_afun('AuxY');
                    $node->set_deprel('cc');
                }
            }
            # Slash '/' can be punctuation or mathematical symbol.
            # It is difficult to tell automatically but we will make it a symbol if it is not leaf (and does not head coordination).
            elsif($node->form() eq '/' && !$node->is_leaf() && !$node->is_coap_root())
            {
                $node->iset()->set('pos', 'sym');
                if($node->afun() eq 'AuxG')
                {
                    $node->set_afun('AuxY');
                    $node->set_deprel('cc');
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
            if($node->afun() eq 'AuxG')
            {
                $node->set_afun('AuxY');
                $node->set_deprel('cc');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Convert analytical functions to universal dependency relations.
# This new version (2015-03-25) is meant to act before any structural changes,
# even before coordination gets reshaped.
#------------------------------------------------------------------------------
sub afun_to_udeprel
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        $afun = '' if(!defined($afun));
        my $deprel;
        my $parent = $node->parent();
        # The top nodes (children of the root) must be labeled 'root'.
        # We will now extend the label in cases where we may later need to distinguish the original afun.
        if($parent->is_root())
        {
            # In verbless elliptic sentences the conjunction has no child (except for punctuation). It will remain attached as root.
            # Example (sk): A ak áno, tak načo? = And if so, then why?
            my @non_arg_children = grep {$_->afun() !~ m/^Aux[XGKY]$/} ($node->children());
            if($afun eq 'AuxC' && scalar(@non_arg_children)==0)
            {
                $deprel = 'root';
            }
            elsif($afun =~ m/^(Coord|AuxP|AuxC|AuxK|ExD)$/)
            {
                $deprel = 'root:'.lc($afun);
            }
            else # $afun should be 'Pred'
            {
                $deprel = 'root';
            }
        }
        # Punctuation is always 'punct' unless it depends directly on the root (which should happen only if there is just one node and the root).
        # We will temporarily extend the label if it heads coordination so that the coordination can later be reshaped properly.
        elsif($node->is_punctuation())
        {
            if($afun eq 'Coord')
            {
                $deprel = 'punct:coord';
            }
            else
            {
                $deprel = 'punct';
            }
        }
        # Coord marks the conjunction that heads a coordination.
        # (Punctuation heading coordination has been processed earlier and temporarily labeled 'punct:coord'.)
        # Coordinations will be later restructured and the conjunction will be attached as 'cc'.
        elsif($afun eq 'Coord')
        {
            $deprel = 'cc:coord';
        }
        # AuxP marks a preposition. There are two possibilities:
        # 1. It heads a prepositional phrase. The relation of the phrase to its parent is marked at the argument of the preposition.
        # 2. It is a leaf, attached to another preposition, forming a multi-word preposition. (In this case the word can be even a noun.)
        # Prepositional phrases will be later restructured. In the situation 1, the preposition will be attached to its argument as 'case'.
        # In the situation 2, the first word in the multi-word prepositon will become the head and all other parts will be attached to it as 'mwe'.
        elsif($afun eq 'AuxP')
        {
            $deprel = 'case:auxp';
        }
        # AuxC marks a subordinating conjunction that heads a subordinate clause.
        # It will be later restructured and the conjunction will be attached to the subordinate predicate as 'mark'.
        elsif($afun eq 'AuxC')
        {
            $deprel = 'mark:auxc';
        }
        # Predicate: If the node is not the main predicate of the sentence and it has the Pred afun,
        # then it is probably the main predicate of a parenthetical expression.
        # Exception: predicates of coordinate main clauses. This must be solved after coordinations have been reshaped. ###!!! TODO
        elsif($afun eq 'Pred')
        {
            $deprel = 'parataxis';
        }
        # Subject: nsubj, nsubjpass, csubj, csubjpass
        elsif($afun eq 'Sb')
        {
            # Is the parent a passive verb?
            ###!!! This will not catch reflexive passives. TODO: Catch them.
            if($parent->iset()->is_passive())
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $deprel = $node->is_verb() ? 'csubjpass' : 'nsubjpass';
            }
            else # Parent is not passive.
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $deprel = $node->is_verb() ? 'csubj' : 'nsubj';
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
            $deprel = $node->is_verb() ? ($node->is_infinitive() ? 'xcomp' : 'ccomp') : 'dobj';
        }
        # Adverbial modifier: advmod, nmod, advcl
        # Note: UD also distinguishes the relation neg. In Czech, most negation is done using bound morphemes.
        # Separate negative particles exist but they are either ExD (replacing elided negated "to be") or AuxZ ("ne poslední zvýšení cen").
        # Examples: ne, nikoli, nikoliv, ani?, vůbec?
        # I am not sure that we want to distinguish them from the other AuxZ using the neg relation.
        # AuxZ words are mostly adverbs, coordinating conjunctions and particles. Other parts of speech are extremely rare.
        elsif($afun eq 'Adv')
        {
            $deprel = $node->is_verb() ? 'advcl' : $node->is_noun() ? 'nmod' : 'advmod';
        }
        # Attribute of a noun: amod, nummod, nmod, acl
        elsif($afun eq 'Atr')
        {
            # Cardinal number is nummod, ordinal number is amod. It should not be a problem because Interset should categorize ordinals as special types of adjectives.
            # But we cannot use the is_numeral() method because it returns true if pos=num or if numtype is not empty.
            # We also want to exclude pronominal numerals (kolik, tolik, mnoho, málo). These should be det.
            if($node->iset()->pos() eq 'num')
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
            elsif($node->iset()->nametype() =~ m/(giv|sur|prs)/ &&
                  $parent->iset()->nametype() =~ m/(giv|sur|prs)/)
            {
                $deprel = 'name';
            }
            elsif($node->is_foreign() && $parent->is_foreign())
            {
                $deprel = 'foreign';
            }
            elsif($node->is_adjective() && $node->is_pronoun() && $self->agree($node, $parent, 'case'))
            {
                # Warning: In Czech and some other languages the tagset does not distinguish determiners from pronouns.
                # The distinction is done during Interset decoding, using heuristics.
                # It is not final at this place. Later in the fix_determiners() method we may decide to change DET back to PRON.
                # In such case, we will also change det to nmod.
                $deprel = 'det';
            }
            elsif($node->is_adjective())
            {
                $deprel = 'amod';
            }
            elsif($node->is_verb())
            {
                $deprel = 'acl';
            }
            else
            {
                $deprel = 'nmod';
            }
        }
        # AuxA is not an official afun used in HamleDT 2.0. Nevertheless it has been introduced in some (not all)
        # languages by people who want to use the resulting data in TectoMT. It marks articles attached to nouns.
        elsif($afun eq 'AuxA')
        {
            $deprel = 'det';
        }
        # Verbal attribute is analyzed as secondary predication.
        ###!!! TODO: distinguish core arguments (xcomp) from non-core arguments and adjuncts (acl/advcl).
        elsif($afun =~ m/^AtvV?$/)
        {
            $deprel = 'xcomp';
        }
        # Auxiliary verb "být" ("to be"): aux, auxpass
        elsif($afun eq 'AuxV')
        {
            $deprel = $parent->iset()->is_passive() ? 'auxpass' : 'aux';
            # Side effect: We also want to modify Interset. The PDT tagset does not distinguish auxiliary verbs but UPOS does.
            $node->iset()->set('verbtype', 'aux');
        }
        # Reflexive pronoun "se", "si" with inherently reflexive verbs.
        # Unfortunately, previous harmonization to the Prague style abused the AuxT label to also cover Germanic verbal particles and other compound-like stuff with verbs.
        # We have to test for reflexivity if we want to output compound:reflex!
        elsif($afun eq 'AuxT')
        {
            # This appears in Slavic languages, although in theory it could be used in some Romance and Germanic languages as well.
            # It actually also appears in Dutch (but we mixed it with verbal particles there).
            # Most Dutch pronouns used with this label are tagged as reflexive but a few are not.
            if($node->is_reflexive() || $node->is_pronoun())
            {
                $deprel = 'compound:reflex';
            }
            # The Tamil afun CC (compound) has also been converted to AuxT. 11 out of 12 occurrences are tagged as verbs.
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
        elsif($afun eq 'AuxR')
        {
            $deprel = 'auxpass:reflex';
        }
        # AuxZ: intensifier or negation
        elsif($afun eq 'AuxZ')
        {
            # Negation is mostly done using bound prefix ne-.
            # If it is a separate word ("ne už personálním, ale organizačním"; "potřeboval čtyřnohého a ne dvounohého přítele), it is labeled AuxZ.
            ###!!! This is specific to Czech!
            my $lemma = $node->lemma();
            if(defined($lemma) && $lemma eq 'ne')
            {
                $deprel = 'neg';
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
        elsif($afun eq 'Neg')
        {
            $deprel = 'neg';
        }
        # AuxY: Additional conjunction in coordination ... cc
        # AuxY: Subordinating conjunction "jako" ("as") attached to Atv or AtvV, or even Obj (of verbal adjectives) ... mark
        elsif($afun eq 'AuxY')
        {
            if(lc($node->form()) eq 'jako')
            {
                $deprel = 'mark';
            }
            else
            {
                $deprel = 'cc';
            }
        }
        # AuxO: redundant "to" or "si" ("co to znamená pátý postulát dokázat").
        elsif($afun eq 'AuxO')
        {
            $deprel = 'discourse';
        }
        # Apposition
        elsif($afun eq 'Apposition')
        {
            $deprel = 'appos';
        }
        # Punctuation
        ###!!! Since we now label all punctuation (decided by Interset) as punct,
        ###!!! here we only get non-punctuation labeled (by mistake?) AuxG, AuxX or AuxK. What to do with this???
        elsif($afun eq 'AuxG')
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
                $deprel = 'nmod'; ###!!! or nsubj or dobj or whatever
            }
        }
        elsif($afun =~ m/^Aux[XK]$/)
        {
            # AuxX is reserved for commas.
            # AuxK is used for sentence-terminating punctuation, usually a period, an exclamation mark or a question mark.
            log_warn("Node '".$node->form()."' has afun '$afun' but it is not punctuation.");
            $deprel = 'punct';
        }
        ###!!! TODO: ExD with chains of orphans should be stanfordized!
        elsif($afun eq 'ExD')
        {
            # Some ExD are vocatives.
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
        # Set up a fallback so that $deprel is always defined.
        else
        {
            $deprel = 'dep:'.lc($afun);
        }
        # Save the universal dependency relation label with the node.
        $node->set_deprel($deprel);
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
    return if($node->is_root());
    # After processing my children, some of them may have ceased to be my children and some new children may have appeared.
    # This is the result of restructuring a child coordination.
    # Get the new list of children. In addition, we now require that the list is ordered (we have to identify the first conjunct).
    @children = $node->get_children({ordered => 1});
    # We have a coordination if the current node's afun is Coord, i.e. deprel is 'cc:coord', 'punct:coord' or 'root:coord'.
    my $deprel = $node->deprel();
    if($deprel =~ m/:coord/)
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
            # There must not be any node labeled ':coord' and lacking is_member children.
            $deprel =~ s/:coord//;
            $node->set_deprel($deprel);
        }
        else
        {
            # Set the first conjunct as the new head.
            # Its deprel should be already OK. It should not be a nested coordination because we processed the children first.
            my $head = shift(@conjuncts);
            $head->set_parent($node->parent());
            $head->set_is_member($current_coord_is_member);
            # Re-attach the current node and all its children to the new head.
            # Mark conjuncts using the UD relation conj.
            foreach my $conjunct (@conjuncts)
            {
                $conjunct->set_parent($head);
                # If the conjunct is an adposition (AuxP) or subordinating conjunction (AuxC), we must preserve the information for later transformations.
                if($conjunct->deprel() =~ m/:(aux[pc])/)
                {
                    $conjunct->set_deprel('conj:'.$1);
                }
                # Even punctuation is sometimes conjunct (an orphan conjunct with the 'ExD' afun).
                # But we want it to be labeled 'punct' instead of 'conj'.
                elsif($conjunct->deprel() ne 'punct')
                {
                    $conjunct->set_deprel('conj');
                }
                # Clear the is_member flag for all conjuncts. It only made sense in the Prague style.
                $conjunct->set_is_member(0);
            }
            foreach my $dependent (@dependents)
            {
                $dependent->set_parent($head);
            }
            $node->set_parent($head);
            $deprel =~ s/:coord//;
            if($deprel eq 'root')
            {
                $head->set_deprel('root');
                $deprel = $node->is_punctuation() ? 'punct' : 'cc';
            }
            $node->set_deprel($deprel);
        }
    }
}



#------------------------------------------------------------------------------
# Identifies multi-word prepositions and restructures them according to the UD
# guidelines.
#------------------------------------------------------------------------------
sub restructure_compound_prepositions
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # Example multi-word preposition: na rozdíl od (in contrast to).
    # Original annotation: "od" is head, "na" and "rozdíl" depend on it. All three labeled "AuxP". The noun is attached to "od".
    # Desired annotation: "na" is head, "rozdíl" and "od" depend on it, labeled "mwe". "na" is attached to the noun and labeled "case".
    # Most compound prepositions consist of three nodes, some consist of two but we will not apriori restrict the number of nodes.
    for(my $i = 0; $i < $#nodes; $i++)
    {
        my $iord = $nodes[$i]->ord();
        # We cannot identify parts of compound preposition using the POS tag because some parts are nouns.
        # We must use the original dependency label.
        if($nodes[$i]->deprel() =~ m/:auxp/ && $nodes[$i]->is_leaf())
        {
            my $parent = $nodes[$i]->parent();
            my $pord = $parent->ord();
            if($pord > $iord && $parent->deprel() =~ m/^(case|mark):auxp$/)
            {
                my $found = 1;
                my @mwe;
                # We seem to have found a multi-word preposition. Make sure that all nodes between child and parent comply.
                for(my $j = $i+1; $nodes[$j] != $parent; $j++)
                {
                    if($nodes[$j]->deprel() !~ m/:auxp/ || !$nodes[$j]->is_leaf() || $nodes[$j]->parent() != $parent)
                    {
                        $found = 0;
                        last;
                    }
                    push(@mwe, $nodes[$j]);
                }
                if($found)
                {
                    # $nodes[$i] is the first token of the MWE and the new head.
                    # @mwe contains the internal tokens of the MWE, usually just one middle token.
                    # $parent is the last token of the MWE and the old head.
                    $nodes[$i]->set_parent($parent->parent());
                    foreach my $n (@mwe, $parent)
                    {
                        $n->set_parent($nodes[$i]);
                        $n->set_deprel('mwe');
                    }
                    # Re-attach all other children of the original head to the new head.
                    # There should be at least one child (the noun) and possibly also some punctuation etc.
                    my @children = $parent->children();
                    foreach my $child (@children)
                    {
                        $child->set_parent($nodes[$i]);
                    }
                    # Move index to the last word of the MWE, i.e. to the old $parent.
                    $i += scalar(@mwe)+1;
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
        my $deprel = $node->deprel();
        next unless($deprel =~ m/:aux[pc]/);
        # In the prototypical case, the node has just one child and it will swap positions with the child.
        # Known exceptions:
        # - Punctuation children should be attached to the noun and labeled 'punct'.
        # - If this is the first word of a multi-word preposition, all children labeled 'mwe' should be left untouched.
        #   (Multi-word prepositions have been solved prior to coming here.)
        # - If this is the first conjunct in a coordination of prepositional phrases, all 'cc' and 'conj' children should be attached to the noun.
        #   (Coordinations have been transformed prior to coming here.)
        # - If this is a non-first conjunct, it already has the label 'conj'. It will now be re-attached and re-labeled 'case'.
        #   However, the noun should get the 'conj' label and forget its afun (which was hopefully identical to the afun of the first conjunct).
        ###!!! TODO: Decide what to do if this is an orphan conjunct and its afun is 'ExD'.
        ###!!! TODO: Decide what to do in case of a chain of AuxP and AuxC nodes. It is rare (if possible at all) in Czech but it occurred in some languages.
        ###!!! TODO: If the child is also Aux[PC], we should process the chain recursively.
        ###!!! TODO: Are there any prepositions with two or more arguments attached directly to them?
        ###!!! TODO: A preposition or subordinating conjunction may also have multiple children if there is punctuation.
        my $children = $self->get_auxpc_children($node);
        my $n = scalar(@{$children->{args}});
        if($n != 1)
        {
            my $form = $node->form();
            my $phrase = join(' ', map {my $l = $_->lemma(); $l = '_' unless(defined($l)); $l.'/'.$_->afun().'/'.$_->deprel()} ($node->get_children({'add_self' => 1, 'ordered' => 1})));
            if($n == 0)
            {
                # Try to requalify other children (if any) as arguments.
                $children->{args} = $children->{other};
                $n = scalar(@{$children->{args}});
                delete($children->{other});
                # Warn the user if we still have not found an argument.
                if($n == 0)
                {
                    log_warn("Cannot find argument of '$deprel' node '$form': '$phrase'.");
                }
            }
            else
            {
                log_warn("'$deprel' node '$form' has more than one possible arguments: '$phrase'.");
            }
        }
        if($n > 0)
        {
            my $head = shift(@{$children->{args}});
            $head->set_parent($node->parent());
            $node->set_parent($head);
            # Attach punctuation, conjunctions and conjuncts to the new head.
            # If there are other arguments and other children, attach them to the new head, too.
            # Leave mwe nodes where they are.
            foreach my $child (@{$children->{pc}}, @{$children->{auxz}}, @{$children->{args}}, @{$children->{other}})
            {
                $child->set_parent($head);
            }
            # If the Aux[PC] node was a top node, the new head must now take over.
            if($deprel =~ m/^root:/)
            {
                $head->set_deprel('root');
            }
            # If the Aux[PC] node was a non-first conjunct, the new head must now take over.
            elsif($deprel =~ m/^conj:/)
            {
                $head->set_deprel('conj');
            }
        }
        # Even if the adposition is already a leaf (which should not happen), it cannot keep the AuxP label.
        # Even if the conjunction is already a leaf (which should not happen), it cannot keep the AuxC label.
        if($node->parent()->is_verb())
        {
            # Both subordinating conjunctions and prepositions are labeled 'mark' when their argument is a verb.
            $node->set_deprel('mark');
        }
        else
        {
            $deprel = $deprel =~ m/:auxp/ ? 'case' : 'mark';
            $node->set_deprel($deprel);
        }
    }
}



#------------------------------------------------------------------------------
# Sorts out children of an AuxP/AuxC node w.r.t. their future attachment.
#------------------------------------------------------------------------------
sub get_auxpc_children
{
    my $self = shift;
    my $auxnode = shift;
    my $auxlemma = $auxnode->lemma(); $auxlemma = '' if(!defined($auxlemma));
    my $auxafun = $auxnode->afun();
    my @children = $auxnode->get_children({ordered => 1});
    # Punctuation, conjunctions and conjuncts should be re-attached to the new head.
    my @pc;
    # Non-first words of a multi-word preposition should remain attached to the old head (the auxnode).
    my @mwe;
    # Emphasizing words. They should depend on the argument of the preposition but sometimes they depend on the preposition.
    my @auxz;
    # The argument of an adposition (and the new head) is typically a noun or pronoun.
    # The argument of a subordinating conjunction (and the new head) is typically a verb.
    # There should be just one argument but the children are ordered an in case of more than one argument
    # we will pick the first one.
    my @args;
    my @other;
    foreach my $child (@children)
    {
        # We assume that the 'cc', 'conj' and 'mwe' deprels are already in place.
        my $deprel = $child->deprel();
        if($deprel =~ m/^(punct|cc|conj)$/)
        {
            push(@pc, $child);
        }
        elsif($deprel eq 'mwe')
        {
            push(@mwe, $child);
        }
        elsif($deprel =~ m/^(advmod:emph|neg)$/)
        {
            push(@auxz, $child);
        }
        elsif($auxlemma =~ m/^(jako|než-2)$/ &&
                ($child->is_verb() || $child->is_noun() || $child->is_adjective() || $child->is_numeral() ||
                 $child->is_adverb() || $child->is_symbol()) ||
              $auxafun eq 'AuxP' &&
                ($child->is_noun() || $child->is_adjective() || $child->is_numeral() || $child->is_adverb() ||
                 $child->is_symbol()) || # Adverb: "o dost"
              $auxafun eq 'AuxC' && $child->is_verb())
        {
            push(@args, $child);
        }
        else
        {
            push(@other, $child);
        }
    }
    return {'pc' => \@pc, 'mwe' => \@mwe, 'auxz' => \@auxz, 'args' => \@args, 'other' => \@other};
}



#------------------------------------------------------------------------------
# Makes sure that a preposition attached to a verb is labeled 'mark' and not
# 'case'. It is difficult to enforce during restructuring of Aux[PC] phrases
# because there are things like coordinations of AuxP-AuxC chains, so it is not
# immediately apparent that the final head will be a verb.
#------------------------------------------------------------------------------
sub change_case_to_mark_under_verb
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'case' && $node->parent()->is_verb())
        {
            $node->set_deprel('mark');
        }
    }
}



#------------------------------------------------------------------------------
# The colon is sometimes treated as a substitute for the main predicate in the
# PDT (usually the hypothetical predicate would equal to "is").
# Example: "Veletrh GOLF 94 München: 2. – 4. 9." ("GOLF 94 fair Munich:
# September 2 – 9")
# We will make the first part the main constituent, and attach the second part
# as apposition. In some cases the colon is analyzed as copula (and the second
# part is a nominal predicate) so we want to do this before copulas are
# processed. Otherwise the scene will be reshaped and we will not recognize it.
#------------------------------------------------------------------------------
sub colon_pred_to_apposition
{
    my $self  = shift;
    my $root  = shift;
    my @rchildren = $root->get_children({'ordered' => 1});
    if(scalar(@rchildren) >= 1 && $rchildren[0]->form() eq ':' && !$rchildren[0]->is_leaf())
    {
        # Make the first child of the colon the new top node.
        # We want a non-punctuation child. If there are only punctuation children, do not do anything.
        my $colon = shift(@rchildren);
        my @colchildren = $colon->get_children({'ordered' => 1});
        my @npcolchildren = grep {!$_->is_punctuation()} (@colchildren);
        my @pcolchildren = grep {$_->is_punctuation()} (@colchildren);
        if(scalar(@npcolchildren)>=1)
        {
            my $newtop = shift(@npcolchildren);
            $newtop->set_parent($root);
            $newtop->set_deprel('root');
            # The dependency between the new top node and the colon will now be reversed.
            # If it still has afun (afun_to_deprel has not been done yet), we must change Pred to something less explosive.
            $colon->set_parent($newtop);
            $colon->set_deprel('punct');
            # All other children of the colon (if any; probably just one other child) will be attached to the new top node as apposition.
            foreach my $child (@npcolchildren)
            {
                $child->set_parent($newtop);
                $child->set_deprel('appos');
            }
            foreach my $child (@pcolchildren)
            {
                $child->set_parent($newtop);
                $child->set_deprel('punct');
            }
            # There may be other top nodes (children of the root).
            # The sentence-final punctuation would normally be (re)attached to the main verb but it did not work here because we had a colon instead of a verb.
            # Thus we should now reattach the punctuation node to the new top node.
            ###!!! Only do this if there are no other top nodes. Otherwise we would have to investigate whether they are also punctuation
            ###!!! (then they should probably be attached to the new top node) or regular words (then the final punctuation should be
            ###!!! attached to them instead of to what we call "the new top node" here; otherwise we would introduce a non-projectivity).
            if(scalar(@rchildren) == 1 && $rchildren[0]->is_punctuation())
            {
                my $finalpunct = $rchildren[0];
                $finalpunct->set_parent($newtop);
                $finalpunct->set_deprel('punct');
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
        my $deprel = $node->deprel();
        if($deprel eq 'dep:pnom')
        {
            my $pnom = $node;
            my $copula = $node->parent();
            my $grandparent = $copula->parent();
            if(defined($grandparent))
            {
                $pnom->set_parent($grandparent);
                $pnom->set_deprel($copula->deprel());
                # All other children of the copula will be reattached to the nominal predicate.
                # The copula will become a leaf.
                my @children = $copula->children();
                foreach my $child (@children)
                {
                    $child->set_parent($pnom);
                }
                $copula->set_parent($pnom);
                $copula->set_deprel('cop');
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
            $pnode->set_deprel('punct');
        }
    }
}



#------------------------------------------------------------------------------
# Splits numeral types that have the same tag in the PDT tagset and the
# Interset decoder cannot distinguish them because it does not see the word
# forms.
#------------------------------------------------------------------------------
sub classify_numerals
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $iset = $node->iset();
        # Separate multiplicative numerals (jednou, dvakrát, třikrát) and
        # adverbial ordinal numerals (poprvé, podruhé, potřetí).
        if($iset->numtype() eq 'mult')
        {
            # poprvé, podruhé, počtvrté, popáté, ..., popadesáté, posté
            # potřetí, potisící
            if($node->form() =~ m/^po.*[éí]$/i)
            {
                $iset->set('numtype', 'ord');
            }
        }
        # Separate generic numerals
        # for number of kinds (obojí, dvojí, trojí, čtverý, paterý) and
        # for number of sets (oboje, dvoje, troje, čtvery, patery).
        elsif($iset->numtype() eq 'gen')
        {
            if($iset->variant() eq '1')
            {
                $iset->set('numtype', 'sets');
            }
        }
        # Separate agreeing adjectival indefinite numeral "nejeden" (lit. "not one" = "more than one")
        # from indefinite/demonstrative adjectival ordinal numerals (několikátý, tolikátý).
        elsif($node->is_adjective() && $iset->contains('numtype', 'ord') && $node->lemma() eq 'nejeden')
        {
            $iset->add('pos' => 'num', 'numtype' => 'card', 'prontype' => 'ind');
        }
    }
}



#------------------------------------------------------------------------------
# Identifies multi-word numerals and organizes them in chains.
#------------------------------------------------------------------------------
sub restructure_compound_numerals
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # We are looking for sequences of numerals where every two adjacent words
    # are connected with a dependency. The direction of the dependency does not
    # matter. If a numeral is tagged as noun (this could happen to "sto",
    # "tisíc", "milión", "miliarda"), the chain will not include them.
    for(my $i = 0; $i < $#nodes; $i++)
    {
        if($nodes[$i]->iset()->contains('numtype', 'card'))
        {
            my $chain_found = 0;
            for(my $j = $i+1; $j <= $#nodes; $j++)
            {
                if($nodes[$j]->iset()->contains('numtype', 'card') &&
                   ($nodes[$j]->parent() == $nodes[$j-1] || $nodes[$j-1]->parent() == $nodes[$j]))
                {
                    $chain_found = $j-$i;
                }
                else
                {
                    last;
                }
            }
            if($chain_found)
            {
                # Figure out the attachment of the whole chain to the outside world.
                my $minord = $nodes[$i]->ord();
                my $maxord = $nodes[$i+$chain_found]->ord();
                my $parent;
                my $deprel;
                # Incremental reshaping could create temporary cycles and Treex would not allow that.
                # Therefore first attach all participants to the root, then draw the links between them.
                for(my $j = $i; $j <= $i+$chain_found; $j++)
                {
                    my $old_parent_ord = $nodes[$j]->parent()->ord();
                    if($old_parent_ord < $minord || $old_parent_ord > $maxord)
                    {
                        $parent = $nodes[$j]->parent();
                        $deprel = $nodes[$j]->deprel();
                    }
                    $nodes[$j]->set_parent($root);
                }
                # Collect all outside children of the numeral nodes.
                # Later we will attach them to the head numeral.
                my @children;
                for(my $j = $i; $j <= $i+$chain_found; $j++)
                {
                    push(@children, $nodes[$j]->children());
                }
                for(my $j = $i; $j < $i+$chain_found; $j++)
                {
                    $nodes[$j]->set_parent($nodes[$j+1]);
                    $nodes[$j]->set_deprel('compound');
                }
                $nodes[$i+$chain_found]->set_parent($parent);
                $nodes[$i+$chain_found]->set_deprel($deprel);
                foreach my $child (@children)
                {
                    $child->set_parent($nodes[$i+$chain_found]);
                }
                $i += $chain_found;
            }
        }
    }
}



#------------------------------------------------------------------------------
# Makes sure that numerals modify counted nouns, not vice versa. (In PDT, both
# directions are possible under certain circumstances.)
#------------------------------------------------------------------------------
sub push_numerals_down
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Look for genitive nouns and pronouns attached to a numeral.
        if($node->is_noun() && $node->iset()->case() eq 'gen')
        {
            my $noun = $node;
            my $number = $node->parent();
            if($number->is_cardinal())
            {
                $noun->set_parent($number->parent());
                # If the number was already attached as nummod, it does not tell us anything but we do not want to keep nummod for the noun head.
                my $deprel = $number->deprel();
                $deprel = 'nmod' if($deprel =~ m/^(nummod|det:nummod)$/);
                $noun->set_deprel($deprel);
                $number->set_parent($noun);
                $number->set_deprel($number->iset()->prontype() eq '' ? 'nummod:gov' : 'det:numgov');
                # All children of the number, except for parts of compound number, must be re-attached to the noun because they modify the whole phrase.
                my @children = grep {$_->deprel() ne 'compound'} $number->children();
                foreach my $child (@children)
                {
                    $child->set_parent($noun);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Changes some determiners to pronouns, based on syntactic annotation.
# The Interset driver of the PDT tagset divides pronouns to pronouns and
# determiners. It knows that some pronouns are capable of acting as determiners
# nevertheless, they can still be used as pronouns (replacing a noun phrase
# instead of modifying it). This method tries to figure out whether the word
# actually modifies a noun phrase as an adjective.
#
# Coordination must have been converted before calling this method, because we
# do not search for effective parent (e.g. in "některého žáka či žákyni").
# Dependency relation labels must have been converted to UD labels.
#------------------------------------------------------------------------------
sub fix_determiners
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # The is_pronoun() method will catch all pronominal words, i.e. UPOS pronouns (pos=noun), determiners (pos=adj),
        # even pronominal adverbs (pos=adv) and undecided words if the source tagset does not have determiners (pos=adj|noun).
        if($node->is_pronoun())
        {
            # The is_adjective() method will catch both pos=adj and pos=adj|noun.
            if($node->is_adjective())
            {
                my $parent = $node->parent();
                my $change = 0; # do not change DET to PRON
                if(!$parent->is_root())
                {
                    # The common pattern is that the parent is a noun (or pronoun) and that it follows the determiner.
                    #  possessive: můj pes (my dog)
                    #  demonstrative: ten pes (that dog)
                    #  interrogative: který pes (which dog)
                    #  indefinite: nějaký pes (some dog)
                    #  total: každý pes (every dog)
                    #  negative: žádný pes (no dog)
                    # Sometimes the determiner can follow the noun, instead of preceding it.
                    #  v Německu samém (in Germany itself)
                    #  té naší (the our)
                    #  to vše (that all)
                    #  nás všechny (us all)
                    # But we want to rule out genitive constructions where one genitive pronoun post-modifies a noun phrase.
                    #  nabídka všech (offer of all) (genitive construction; the words do not agree in case)
                    #  půl tuctu jich (half dozen of them) (genitive construction; the words agree in case because tuctu is incidentially also genitive, but they do not agree in number; in addition, "jich" is a non-possessive personal pronoun which should never become det)
                    #  firmy All - Impex (foreign determiner All; it cannot agree in case because it does not have case)
                    #  děvy samy (girls themselves) (the words agree in case but the afun is Atv, not Atr, thus we should not get through the 'amod' constraint above)
                    # The tree has not changed from the Prague style except for coordination. Nominal predicates still depend on copulas.
                    # If it does not modify a noun (adjective, pronoun), it is not a determiner.
                    $change = 1 if(!$parent->is_noun() && !$parent->is_adjective());
                    # If they do not agree, it is not a determiner.
                    $change = 1 if(!$self->agree($node, $parent, 'case'));
                    # The following Czech pronouns are never used as determiners:
                    # - personal (not possessive) pronouns, including non-possessive reflexives
                    # - *kdo, *co, nic
                    # - "to" in the compound conjunction "a to"
                    if($node->iset()->prontype() eq 'prs' && !$node->is_possessive() ||
                       $node->form() =~ m/(kdo|co|^nic)$/i)
                    {
                        $change = 1;
                    }
                    elsif(lc($node->form()) eq 'to')
                    {
                        my @children = $node->children();
                        if(any {lc($_->form()) eq 'a'} @children)
                        {
                            $change = 1;
                        }
                    }
                    # If it is attached via one of the following relations, it is a pronoun, not a determiner.
                    ###!!! We include 'conj' because conjuncts are more often than not pronouns and we do not want to implement the correct treatment of coordinations.
                    ###!!! Nevertheless it is possible that determiners are coordinated: "ochutnala můj i tvůj oběd".
                    if($node->deprel() =~ m/^(nsubj|dobj|iobj|xcomp|advmod|case|appos|conj|cc|discourse|parataxis|foreign|dep)$/)
                    {
                        $change = 1;
                    }
                }
                else
                {
                    # Neither pronoun nor determiner normally depend directly on the root.
                    # They do so only in the case of ellipsis. Then we will call them pronouns, not determiners (usually it is their verbal head what has been deleted).
                    $change = 1;
                }
                if($change)
                {
                    # Change DET to PRON by changing Interset part of speech from adj to noun.
                    $node->iset()->set('pos', 'noun');
                    # The current deprel is probably det but that is not compatible with the word being tagged PRON. Change the deprel as well.
                    $node->set_deprel('nmod') if($node->deprel() eq 'det');
                }
                else
                {
                    # We do not want words undecided between determiners and pronouns (pos=adj|noun).
                    # Once we decided that a word is determiner, we will state it clearly (pos=adj)!
                    $node->iset()->set('pos', 'adj');
                }
            } # if pos=adj or something + adj
            # Pronominal numerals (quantifiers) "kolik", "mnoho" etc. are not determiners if they are not used together with a counted noun.
            # They may be used e.g. as an object: "Kolik to stojí?" = "How-much it costs?"
            # Important: We assume that the high-value numerals have been pushed down first.
            elsif($node->is_numeral())
            {
                if($node->deprel() !~ m/^det(:numgov|:nummod)?$/)
                {
                    # If the dependency relation is not determiner-like, we do not want it tagged DET.
                    # Then the next acceptable tag is PRON, which means we have to change Interset pos to noun.
                    $node->iset()->set('pos', 'noun');
                }
            }
        } # if is pronoun
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
# Sanity check: everything that is tagged DET must be attached as det.
#------------------------------------------------------------------------------
sub check_determiners
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = defined($node->form()) ? $node->form() : '<EMPTY>';
        my $pform = $node->parent()->is_root() ? '<ROOT>' : defined($node->parent()->form()) ? $node->parent()->form() : '<EMPTY>';
        my $npform;
        if($node->parent()->ord() < $node->ord())
        {
            $npform = "($pform) $form";
        }
        else
        {
            $npform = "$form ($pform)";
        }
        # Determiner is a pronominal adjective.
        my $iset = $node->iset();
        if($iset->upos() eq 'DET')
        {
            if($node->deprel() !~ m/^det(:numgov|:nummod)?$/)
            {
                log_warn($npform.' is tagged DET but is not attached as det but as '.$node->deprel());
            }
        }
        elsif($node->deprel() eq 'det')
        {
            if($iset->upos() ne 'DET')
            {
                log_warn($npform.' is attached as det but is not tagged DET');
            }
        }
    }
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
        my $form = $node->form();
        my $afun = $node->afun();
        if($form =~ m/^[so]$/i && !$node->is_adposition() && $afun eq 'AuxP')
        {
            # We do not know what the correct afun would be. There is a chance it would be Apposition or Atr but it is not guaranteed.
            # On the other hand, any of the two, even if incorrect, is much better than AuxP, which would trigger various transformations,
            # inappropriate in this context.
            $node->set_afun('Atr');
        }
    }
}



#------------------------------------------------------------------------------
# The top nodes (children of root) in incomplete sentences were temporarily
# labeled 'root:exd' to save the information during transformations. Now it
# must be reduced to 'root' because 'root:exd' is not a valid universal
# dependency relation.
#------------------------------------------------------------------------------
sub relabel_top_nodes
{
    my $self  = shift;
    my $root  = shift;
    my @topnodes = $root->children();
    foreach my $node (@topnodes)
    {
        # We might relabel it regardless what the previous label was.
        # But at present we only relabel 'root:exd' (incomplete sentences) and 'root:auxk' (sentences with punctuation only)
        # to see whether there are other possible issues.
        if($node->deprel() =~ m/^root:(exd|auxk)$/)
        {
            $node->set_deprel('root');
        }
    }
}



#------------------------------------------------------------------------------
# Relabel subordinate clauses. In the Croatian SETimes corpus, their predicates
# are labeled 'Pred', which translates as 'parataxis'. But we want to
# distinguish the various types of subordinate clauses instead.
#------------------------------------------------------------------------------
sub relabel_subordinate_clauses
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if($deprel eq 'parataxis')
        {
            my $parent = $node->parent();
            next if($parent->is_root());
            my @marks = grep {$_->deprel() eq 'mark'} ($node->children());
            # We do not know what to do when there is no mark. Perhaps it is indeed a parataxis?
            next if(scalar(@marks)==0);
            # Relative clauses modify a noun. They substitute for an adjective.
            if($parent->is_noun())
            {
                $node->set_deprel('acl');
                foreach my $mark (@marks)
                {
                    # The Croatian treebank analyzes both subordinating conjunctions and relative pronouns
                    # the same way. We want to separate them again. Pronouns should not be labeled 'mark'.
                    # They probably fill a slot in the frame of the subordinate verb: 'nsubj', 'dobj' etc.
                    if($mark->is_pronoun() && $mark->is_noun())
                    {
                        my $case = $mark->iset()->case();
                        if($case eq 'nom' || $case eq '')
                        {
                            $mark->set_deprel('nsubj');
                        }
                        else
                        {
                            $mark->set_deprel('dobj');
                        }
                    }
                }
            }
            # Complement clauses depend on a verb that requires them as argument.
            # Examples: he says that..., he believes that..., he hopes that...
            elsif(any {$_->lemma() eq 'da'} (@marks))
            {
                $node->set_deprel('ccomp');
            }
            # Adverbial phrases modify a verb. They substitute for an adverb.
            # Example: ... if he passes the exam.
            else
            {
                $node->set_deprel('advcl');
            }
        }
    }
}



#------------------------------------------------------------------------------
# In the Croatian SETimes corpus, given name of a person depends on the family
# name, and the relation is labeled as apposition. Change the label to 'name'.
#------------------------------------------------------------------------------
sub relabel_appos_name
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if($deprel eq 'appos')
        {
            my $parent = $node->parent();
            next if($parent->is_root());
            if($node->is_proper_noun() && $parent->is_proper_noun() && $self->agree($node, $parent, 'case'))
            {
                $node->set_deprel('name');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::Udep

Converts dependency trees from the HamleDT/Prague style to the Universal
Dependencies. This block is experimental. In the future, it may be split into
smaller blocks, moved elsewhere in the inheritance hierarchy or otherwise
rewritten. It is also possible (actually quite likely) that the current
Harmonize* blocks will be modified to directly produce Universal Dependencies,
which will become our new default central annotation style.

=back

=cut

# Copyright 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

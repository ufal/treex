package Treex::Block::HamleDT::Udep;
use utf8;
use open ':utf8';
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::UD;
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
    $self->convert_deprels($root);
    $self->remove_null_pronouns($root);
    $self->split_tokens_on_underscore($root);
    $self->relabel_appos_name($root);
    # The most difficult part is detection of coordination, prepositional and
    # similar phrases and their interaction. It will be done bottom-up using
    # a tree of phrases that will be then projected back to dependencies, in
    # accord with the desired annotation style. See Phrase::Builder for more
    # details on how the source tree is decomposed. The construction parameters
    # below say how should the resulting dependency tree look like. The code
    # of the builder knows how the INPUT tree looks like (including the deprels
    # already converted from Prague to the UD set).
    my $builder = new Treex::Tool::PhraseBuilder::UD
    (
        'prep_is_head'           => 0,
        'cop_is_head'            => 0,
        'coordination_head_rule' => 'first_conjunct',
        'counted_genitives'      => $self->language() ne 'la'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->change_case_to_mark_under_verb($root);
    $self->fix_jak_znamo($root);
    $self->classify_numerals($root);
    $self->fix_determiners($root);
    $self->relabel_subordinate_clauses($root);
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
        # '%' (percent) and '$' (dollar) will be tagged SYM regardless their
        # original part of speech (probably PUNCT or NOUN). Note that we do not
        # require that the token consists solely of the symbol character.
        # Especially with '$' there are tokens like 'US$', 'CR$' etc. that
        # should be included.
        if($node->form() =~ m/[\$%]$/)
        {
            $node->iset()->set('pos', 'sym');
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
            elsif($node->form() eq '/' && !$node->is_leaf() && !$node->is_coap_root())
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
        elsif($deprel eq 'Coord')
        {
            $deprel = 'cc:coord';
        }
        # AuxP marks a preposition. There are two possibilities:
        # 1. It heads a prepositional phrase. The relation of the phrase to its parent is marked at the argument of the preposition.
        # 2. It is a leaf, attached to another preposition, forming a multi-word preposition. (In this case the word can be even a noun.)
        # Prepositional phrases will be later restructured. In the situation 1, the preposition will be attached to its argument as 'case'.
        # In the situation 2, the first word in the multi-word prepositon will become the head and all other parts will be attached to it as 'mwe'.
        elsif($deprel eq 'AuxP')
        {
            $deprel = 'case:auxp';
        }
        # AuxC marks a subordinating conjunction that heads a subordinate clause.
        # It will be later restructured and the conjunction will be attached to the subordinate predicate as 'mark'.
        elsif($deprel eq 'AuxC')
        {
            $deprel = 'mark:auxc';
        }
        # Predicate: If the node is not the main predicate of the sentence and it has the Pred deprel,
        # then it is probably the main predicate of a parenthetical expression.
        # Exception: predicates of coordinate main clauses. This must be solved after coordinations have been reshaped. ###!!! TODO
        elsif($deprel eq 'Pred')
        {
            $deprel = 'parataxis';
        }
        # Subject: nsubj, nsubjpass, csubj, csubjpass
        elsif($deprel eq 'Sb')
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
        elsif($deprel eq 'Obj')
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
        elsif($deprel eq 'Adv')
        {
            $deprel = $node->is_verb() ? 'advcl' : $node->is_noun() ? 'nmod' : 'advmod';
        }
        # Attribute of a noun: amod, nummod, nmod, acl
        elsif($deprel eq 'Atr')
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
            elsif($node->is_determiner() && $self->agree($node, $parent, 'case'))
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
        # Auxiliary verb "být" ("to be"): aux, auxpass
        elsif($deprel eq 'AuxV')
        {
            $deprel = $parent->iset()->is_passive() ? 'auxpass' : 'aux';
            # Side effect: We also want to modify Interset. The PDT tagset does not distinguish auxiliary verbs but UPOS does.
            $node->iset()->set('verbtype', 'aux');
        }
        # Reflexive pronoun "se", "si" with inherently reflexive verbs.
        # Unfortunately, previous harmonization to the Prague style abused the AuxT label to also cover Germanic verbal particles and other compound-like stuff with verbs.
        # We have to test for reflexivity if we want to output expl!
        elsif($deprel eq 'AuxT')
        {
            # This appears in Slavic languages, although in theory it could be used in some Romance and Germanic languages as well.
            # It actually also appears in Dutch (but we mixed it with verbal particles there).
            # Most Dutch pronouns used with this label are tagged as reflexive but a few are not.
            if($node->is_reflexive() || $node->is_pronoun())
            {
                $deprel = 'expl';
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
            $deprel = 'auxpass:reflex';
        }
        # AuxZ: intensifier or negation
        elsif($deprel eq 'AuxZ')
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
        elsif($deprel eq 'Neg')
        {
            $deprel = 'neg';
        }
        # AuxY: Additional conjunction in coordination ... cc
        # AuxY: Subordinating conjunction "jako" ("as") attached to Atv or AtvV, or even Obj (of verbal adjectives) ... mark
        elsif($deprel eq 'AuxY')
        {
            if(lc($node->form()) eq 'jako')
            {
                if(defined($parent->form()) && lc($parent->form()) eq 'když')
                {
                    # Since "když" is probably also mark:auxc, this will make "jako když" a multi-word conjunction.
                    $deprel = 'mark:auxc';
                }
                else
                {
                    $deprel = 'mark';
                }
            }
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
                $deprel = 'nmod'; ###!!! or nsubj or dobj or whatever
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
            $deprel = 'dep:'.lc($deprel);
        }
        # Save the universal dependency relation label with the node.
        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# The AnCora treebanks of Catalan and Spanish contain empty nodes representing
# elided subjects. These nodes are typically leaves (but I don't know whether
# it is guaranteed). Remove them.
#------------------------------------------------------------------------------
sub remove_null_pronouns
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->form() eq '_' && $node->is_pronoun())
        {
            if($node->is_leaf())
            {
                $node->remove();
            }
            else
            {
                log_warn('Cannot remove NULL node that is not leaf.');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Some treebanks have multi-word expressions collapsed to one node and the
# original words are connected with the underscore character. For example, in
# Portuguese there is the token "Ministério_do_Planeamento_e_Administração_do_Território".
# This is not allowed in Universal Dependencies. Multi-word expressions must be
# split again and the individual words can then be connected using relations
# that will mark the multi-word expression.
#------------------------------------------------------------------------------
sub split_tokens_on_underscore
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $form = $node->form();
        if(defined($form) && $form =~ m/._./)
        {
            my @words = split(/_/, $node->form());
            my $n = scalar(@words);
            # If the MWE is tagged as proper noun then the words will also be
            # proper nouns and they will be connected using the 'name' relation.
            # We have to ignore that some of these proper "nouns" are in fact
            # adjectives (e.g. "San" in "San Salvador"). But we will not ignore
            # function words such as "de". These are language-specific.
            if($node->is_proper_noun())
            {
                # Generate nodes for the new words.
                my @new_nodes = $self->generate_subnodes(\@nodes, $i, \@words, 'name');
                # Were there any function words? Approximation: all-lowercase words within named entities are probably function words.
                ###!!! Note that this will not recognize a function word if it is the first word of the MWE (the articles are likely to occur first).
                my @fw = grep {lc($_) eq $_} (@words);
                # Relatively easy: three or more words, the second word from right is /(de|do|da|dos|das)/.
                if($n >= 3 && scalar(@fw) == 1 && $words[$n-2] =~ m/^(de|do|da|dos|das)$/)
                {
                    # Only now we can reattach the function words. We could not do it before all new nodes were created.
                    ###!!! We assume that the second word is the only function word albeit we have not checked that the third word is not.
                    $new_nodes[$n-3]->iset()->set_hash({'pos' => 'adp', 'adpostype' => 'prep'});
                    $new_nodes[$n-3]->set_parent($new_nodes[$n-2]);
                    $new_nodes[$n-3]->set_deprel('case');
                }
                elsif(scalar(@fw) > 0)
                {
                    log_warn("Function words in the named entity '".join(' ', @words)."' may not have been attached correctly.");
                }
            }
            # Compound preposition.
            elsif($node->is_adposition())
            {
                # Generate nodes for the new words.
                my @new_nodes = $self->generate_subnodes(\@nodes, $i, \@words, 'mwe');
                # abaixo_de, acerca_de, acima_de
                if($n == 2 && $words[1] =~ m/^(de|a)$/i)
                {
                    $node->iset()->set_hash({'pos' => 'adv'});
                    $new_nodes[0]->iset()->set_hash({'pos' => 'adp', 'adpostype' => 'prep'});
                }
                # à_beira_de, a_cargo_de, a_coberto_de
                ###!!! but: obra_do_mestre
                elsif($n == 3)
                {
                    $node->iset()->set_hash({'pos' => 'adp', 'adpostype' => 'prep'});
                    $new_nodes[0]->iset()->set_hash({'pos' => 'noun', 'nountype' => 'com'});
                    $new_nodes[1]->iset()->set_hash({'pos' => 'adp', 'adpostype' => 'prep'});
                }
                # desde_há
                # in_loco
                # para_os_lados_de
                # tal_como
                else
                {
                    log_warn("The compound preposition '".join(' ', @words)."' may not have been decomposed correctly.");
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# This method is called at several places in split_tokens_on_underscore() and
# it is responsible for creating the new nodes, distributing words and lemmas
# connecting the new subtree in a canonical way and taking care of ords.
#------------------------------------------------------------------------------
sub generate_subnodes
{
    my $self = shift;
    my $nodes = shift; # ArrayRef: all existing nodes, ordered
    my $i = shift; # index of the current node (this node will be split)
    my $node = $nodes->[$i];
    my $ord = $node->ord();
    my $words = shift; # ArrayRef: word forms to generate from the current node
    my $n = scalar(@{$words});
    my $deprel = shift; # deprel to use when connecting the new nodes to the current one
    my @lemmas = split(/_/, $node->lemma());
    if(scalar(@lemmas) != $n)
    {
        log_warn("MWE '".$node->form()."' contains $n words but its lemma '".$node->lemma()."' contains ".scalar(@lemmas)." words.");
    }
    my @new_nodes;
    for(my $j = 1; $j < $n; $j++)
    {
        my $new_node = $node->create_child();
        $new_node->_set_ord($ord+$j);
        $new_node->set_form($words->[$j]);
        my $lemma = $lemmas[$j];
        $lemma = '_' if(!defined($lemma));
        $new_node->set_lemma($lemma);
        # Copy all Interset features. It may be wrong, e.g. if we are splitting "Presidente_da_República", the MWE may be masculine but "República" is not.
        # Unfortunately there is no dictionary-independent way to deduce the features of the individual words.
        $new_node->set_iset($node->iset());
        $new_node->set_deprel($deprel);
        push(@new_nodes, $new_node);
    }
    # The original node will now represent only the first word.
    $node->set_form($words->[0]);
    $node->set_lemma($lemmas[0]);
    # Adjust ords of the subsequent old nodes!
    for(my $j = $i + 1; $j <= $#{$nodes}; $j++)
    {
        $nodes->[$j]->_set_ord( $ord + $n + ($j - $i - 1) );
    }
    # Return the list of new nodes.
    return @new_nodes;
}



#------------------------------------------------------------------------------
# In the Croatian SETimes corpus, given name of a person depends on the family
# name, and the relation is labeled as apposition. Change the label to 'name'.
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
                $node->set_deprel('name');
            }
        }
    }
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
# The two Czech words "jak známo" ("as known") are attached as ExD siblings in
# the Prague style because there is missing copula. However, in UD the nominal
# predicate "známo" is the head.
#------------------------------------------------------------------------------
sub fix_jak_znamo
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i<$#nodes; $i++)
    {
        my $n0 = $nodes[$i];
        my $n1 = $nodes[$i+1];
        if(defined($n0->form()) && lc($n0->form()) eq 'jak' &&
           defined($n1->form()) && lc($n1->form()) eq 'známo' &&
           $n0->parent() == $n1->parent())
        {
            $n0->set_parent($n1);
            $n0->set_deprel('mark');
            $n1->set_deprel('advcl') if(!defined($n1->deprel()) || $n1->deprel() eq 'dep');
            # If the expression is delimited by commas, the commas should be attached to "známo".
            if($i>0 && $nodes[$i-1]->parent() == $n1->parent() && defined($nodes[$i-1]->form()) && $nodes[$i-1]->form() =~ m/^[-,]$/)
            {
                $nodes[$i-1]->set_parent($n1);
                $nodes[$i-1]->set_deprel('punct');
            }
            if($i+2<=$#nodes && $nodes[$i+2]->parent() == $n1->parent() && defined($nodes[$i+2]->form()) && $nodes[$i+2]->form() =~ m/^[-,]$/)
            {
                $nodes[$i+2]->set_parent($n1);
                $nodes[$i+2]->set_deprel('punct');
            }
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
    ###!!! Do not do anything for Maltese. There is no tree structure we could
    ###!!! rely on. This is definitely not the best place to turn this off, we
    ###!!! need a more general solution! But right now a quick hack is needed.
    return if($self->language() eq 'mt');
    ###!!!
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # The is_pronominal() method will catch all pronominal words, i.e. UPOS pronouns (pos=noun), determiners (pos=adj),
        # even pronominal adverbs (pos=adv) and undecided words if the source tagset does not have determiners (pos=adj|noun).
        if($node->is_pronominal())
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
                    #  děvy samy (girls themselves) (the words agree in case but the deprel is Atv, not Atr, thus we should not get through the 'amod' constraint above)
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
            # But beware: some numerals are adverbs and not pronouns (e.g. Portuguese "mais").
            elsif($node->is_numeral() && !$node->is_adverb())
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
        $form = '' if(!defined($form));
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
            elsif(any {my $l = $_->lemma(); defined($l) && $l eq 'da'} (@marks))
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

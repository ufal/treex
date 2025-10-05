package Treex::Block::HamleDT::Udep;
use utf8;
use open ':utf8';
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::PragueToUD;
extends 'Treex::Core::Block';

#------------------------------------------------------------------------------
# Reads a Prague-style tree and transforms it to Universal Dependencies.
#------------------------------------------------------------------------------
sub process_atree
{
    my ($self, $root) = @_;
    $self->remove_null_pronouns($root);
    # The most difficult part is detection of coordination, prepositional and
    # similar phrases and their interaction. It will be done bottom-up using
    # a tree of phrases that will be then projected back to dependencies, in
    # accord with the desired annotation style. See Phrase::Builder for more
    # details on how the source tree is decomposed. The construction parameters
    # below say how should the resulting dependency tree look like. The code
    # of the builder knows how the INPUT tree looks like (including the deprels
    # already converted from Prague to the UD set).
    my $builder = Treex::Tool::PhraseBuilder::PragueToUD->new
    (
        'prep_is_head'           => 0,
        'cop_is_head'            => 0,
        'coordination_head_rule' => 'first_conjunct',
        'counted_genitives'      => $root->language ne 'la'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    # The 'cop' relation can be recognized only after transformations.
    $self->tag_copulas_aux($root);
    $self->fix_unknown_tags($root);
    # Look for prepositional objects (must be done after transformations).
    $self->relabel_oblique_objects($root);
    # Look for objects under nouns. It must be done after transformations
    # because we may have not seen the noun previously (because of intervening
    # AuxP and Coord nodes). A noun can be a predicate and then it can have
    # a subject and oblique dependents. But it cannot have an object.
    $self->relabel_objects_under_nominals($root);
    $self->distinguish_acl_from_amod($root);
    $self->relabel_demonstratives_with_clauses($root);
    $self->relabel_postmodifying_determiners($root);
    $self->raise_dependents_of_quantifiers($root);
    $self->change_case_to_mark_under_verb($root);
    $self->dissolve_chains_of_auxiliaries($root);
    $self->raise_children_of_fixed($root);
    $self->relabel_subordinate_clauses($root);
    ###!!! The following method removes symptoms but we may want to find and remove the cause.
    $self->fix_multiple_subjects($root);
    $self->check_ncsubjpass_when_auxpass($root);
    $self->raise_punctuation_from_coordinating_conjunction($root);
    # It is possible that there is still a dependency labeled 'predn'.
    # If it wasn't right under root in the beginning (because of AuxC for example)
    # but it got there during later transformations, it was not processed
    # (because the root does not take part in any specific constructions).
    # So we now simply relabel it as parataxis.
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'predn')
        {
            $node->set_deprel('parataxis');
        }
    }
    ###!!! The EasyTreex extension of Tred currently does not display values of the deprel attribute.
    ###!!! Copy them to conll/deprel (which is displayed) until we make Tred know deprel.
    @nodes = $root->get_descendants({'ordered' => 1});
    if(1)
    {
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
    # Some of the above transformations may have split or removed nodes.
    # Make sure that the full sentence text corresponds to the nodes again.
    ###!!! Note that for the Prague treebanks this may introduce unexpected differences.
    ###!!! If there were typos in the underlying text or if numbers were normalized from "1,6" to "1.6",
    ###!!! the sentence attribute contains the real input text, but it will be replaced by the normalized word forms now.
    $root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Prepositional objects are considered oblique in many languages, although this
# is not a universal rule. They should be labeled "obl:arg" instead of "obj".
# We have tried to identify them during deprel conversion but some may have
# slipped through because of interaction with coordination or apposition.
#------------------------------------------------------------------------------
sub relabel_oblique_objects
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^i?obj(:|$)/)
        {
            if(!$self->is_core_argument($node))
            {
                $node->set_deprel('obl:arg');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Tells for a noun phrase in a given language whether it can be a core argument
# of a verb, based on its morphological case and adposition, if any. This
# method must be called after tree transformations because we look for the
# adposition among children of the current node, and we do not expect
# coordination to step in our way.
#------------------------------------------------------------------------------
sub is_core_argument
{
    my $self = shift;
    my $node = shift;
    my $language = $self->language();
    my @children = $node->get_children({'ordered' => 1});
    # Are there adpositions or other case markers among the children?
    my @adp = grep {$_->deprel() =~ m/^case(:|$)/} (@children);
    my $adp = scalar(@adp);
    # In Slavic and some other languages, the case of a quantified phrase may
    # be determined by the quantifier rather than by the quantified head noun.
    # We can recognize such quantifiers by the relation nummod:gov or det:numgov.
    my @qgov = grep {$_->deprel() =~ m/^(nummod:gov|det:numgov)$/} (@children);
    my $qgov = scalar(@qgov);
    # Case-governing quantifier even neutralizes the oblique effect of some adpositions
    # because there are adpositional quantified phrases such as this Czech one:
    # Výbuch zranil kolem padesáti lidí.
    # ("Kolem padesáti lidí" = "around fifty people" acts externally
    # as neuter singular accusative, but internally its head "lidí"
    # is masculine plural genitive and has a prepositional child.)
    ###!!! We currently ignore all adpositions if we see a quantified phrase
    ###!!! where the quantifier governs the case. However, not all adpositions
    ###!!! should be neutralized. In Czech, the prepositions "okolo", "kolem",
    ###!!! "na", "přes", and perhaps also "pod" can be neutralized,
    ###!!! although there may be contexts in which they should not.
    ###!!! Other prepositions may govern the quantified phrase and force it
    ###!!! into accusative, but the whole prepositional phrase is oblique:
    ###!!! "za třicet let", "o šest atletů".
    $adp = 0 if($qgov);
    # There is probably just one quantifier. We do not have any special rule
    # for the possibility that there are more than one.
    my $caseiset = $qgov ? $qgov[0]->iset() : $node->iset();
    # Tamil: dative, instrumental and prepositional objects are oblique.
    # Note: nominals with unknown case will be treated as possible core arguments.
    if($language eq 'ta')
    {
        return !$caseiset->is_dative() && !$caseiset->is_instrumental() && !$adp;
    }
    # Default: prepositional objects are oblique.
    # Balto-Slavic languages: genitive, dative, locative and instrumental cases are oblique.
    else
    {
        return !$adp
          && !$caseiset->is_genitive()
          && !$caseiset->is_dative()
          && !$caseiset->is_locative()
          && !$caseiset->is_ablative()
          && !$caseiset->is_instrumental();
    }
}



#------------------------------------------------------------------------------
# Nominals can be predicates and then they can have subject and oblique
# dependents. But they cannot have objects.
#------------------------------------------------------------------------------
sub relabel_objects_under_nominals
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my $deprel = $node->deprel();
        if(($parent->is_noun() || $parent->is_pronominal() || $parent->is_numeral()) && $deprel =~ m/^i?obj(:|$)/)
        {
            $deprel = 'nmod';
            $node->set_deprel($deprel);
        }
    }
}



#------------------------------------------------------------------------------
# Distinguishes adnominal clauses headed by adjectives from simple adjectival
# modifiers. This involves in particular passive participles, which are tagged
# ADJ in (Czech) UD, but also normal adjectives with copulas. In the generic
# conversion, any adjective attached to a noun as Atr was converted to amod,
# but we could not look at the adjective's children there; now we can.
#------------------------------------------------------------------------------
sub distinguish_acl_from_amod
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^amod(:|$)/)
        {
            # Any of the following among the children signals that the adjective heads
            # a clause, hence its own incoming dependency should be acl rather than amod.
            if(any {$_->deprel() =~ m/^([nc]subj|cop|aux)(:|$)/} ($node->children()))
            {
                $node->set_deprel('acl');
            }
        }
    }
}



#------------------------------------------------------------------------------
# In some languages, demonstratives are used as linkers between subordinate
# clauses and their governors to provide the required case (Czech "snaha *o to*,
# aby... CLAUSE"). Demonstratives are typically tagged DET. If the governor is
# a nominal, the previous functions may have guessed that the relation should
# be 'det'. However, in this case it should be rather 'nmod'.
#------------------------------------------------------------------------------
sub relabel_demonstratives_with_clauses
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'det')
        {
            # Include also 'amod' because of things like "ploch se vším možným"
            # (det(ploch, vším); amod(vším, možným); the det should be nmod or
            # it should be flipped, "možným" should be head but the whole thing
            # should still depend on "plochy" as nmod).
            my @clauses = grep {$_->deprel() =~ m/^(acl|amod|nmod|ccomp|dep)(:|$)/} ($node->children());
            # "v koalici, ať již jakékoli/det"
            my @claudeps = grep {$_->deprel() =~ m/^(mark)(:|$)/} ($node->children());
            if(scalar(@clauses) > 0)
            {
                $node->set_deprel('nmod');
            }
            elsif(scalar(@claudeps) > 0)
            {
                $node->set_deprel('acl');
            }
        }
    }
}



#------------------------------------------------------------------------------
# A generalization of relabel_demonstratives_with_clauses(): Determiners in the
# languages that we process here (mostly Czech) always precede the noun they
# modify. If a word tagged DET follows its parent, the relation should not be
# 'det'. But the first conversion step may have suggested det if the parent is
# a noun. We could not fix it then because the structure had not been conver-
# ted; now we can.
#------------------------------------------------------------------------------
sub relabel_postmodifying_determiners
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # Do not relabel det:numgov. They can postmodify ("v každém městě jich
        # najdeme několik" – "několik" depends on "jich"). Also, we want to keep
        # their label including the subtype so we can find all quantifiers.
        next if($node->deprel() ne 'det');
        # Premodifying determiners are OK (in the languages we are interested in).
        next if($node->ord() < $node->parent()->ord());
        # Although rare in modern standard Czech, poetic and old texts can contain
        # agreeing determiners after the noun. Some determiners are more likely
        # than others to occur in such positions:
        # - "v Německu samém" ("samém" is det and it agrees with "Německu")
        # - "v Silvě jeho" ("jeho" = "his" is possessive and it would be treated
        #   as det if before the noun ("v jeho Silvě"), although it cannot inflect
        #   to show agreement)
        # - "smlouva tato" (postponed agreeing demonstrative)
        next if($self->agree($node, $node->parent(), 'case') && scalar($node->children()) == 0);
        # Now we probably have a demonstrative or total that heads a nominal and
        # just incidentally depends on a previous noun. Or pronoun. It includes
        # examples like "něco takového", where a partitive-genitive depends on
        # another pronoun or even determiner.
        $node->set_deprel('nmod');
    }
}



#------------------------------------------------------------------------------
# In some languages, indefinite quantifiers morphologically govern the counted
# noun (Czech "několik poslanců" = "several representatives"). In PDT, the
# quantifier was the head, but in UD the relation was turned around and labeled
# 'det:numgov'. There may still be dependents (apposition, "jako"-depictives),
# which were originally attached to the quantifier. They should now be re-
# attached to the new head, i.e., to the counted noun.
#------------------------------------------------------------------------------
sub raise_dependents_of_quantifiers
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # We could restrict the parent's deprel to 'det:numgov' but there are
        # other constructions where the determiner is not quantifier (but
        # demonstrative, totalizer etc.) and they have a similar problem.
        if($node->deprel() =~ m/^(amod|nummod|nmod|appos|acl|advcl|xcomp|dep)(:|$)/ && $node->parent()->deprel() =~ m/^det(:|$)/)
        {
            $node->set_parent($node->parent()->parent());
        }
    }
}




#------------------------------------------------------------------------------
# Since UD v2, verbal copulas must be tagged AUX and not VERB. We cannot check
# this during the deprel conversion because we do not always see the real
# copula as the parent of the Pnom node (hint: coordination).
#------------------------------------------------------------------------------
sub tag_copulas_aux
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'cop' && $node->is_verb())
        {
            $node->iset()->set('verbtype', 'aux');
            $node->set_tag('AUX');
        }
    }
}



#------------------------------------------------------------------------------
# Sometimes the UPOS tag is unknown ("X") but the dependency relation tells us
# what the probable part of speech is. This method will change unknown tags to
# specific tags if there are enough clues.
#------------------------------------------------------------------------------
sub fix_unknown_tags
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->tag() eq 'X')
        {
            if($node->deprel() =~ m/^advmod(:|$)/)
            {
                $node->iset()->set('pos', 'adv');
                $node->set_tag('ADV');
            }
        }
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
# UD guidelines disallow chains of auxiliary verbs. Regardless whether there is
# hierarchy in application of grammatical rules, all auxiliaries should be
# attached directly to the main verb (example [en] "could have been done").
#------------------------------------------------------------------------------
sub dissolve_chains_of_auxiliaries
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # An auxiliary verb may be attached to another auxiliary verb in coordination ([cs] "byl a bude prodáván").
        # Thus we must check whether the deprel is aux (or aux:pass); it is not important whether the UPOS tag is AUX.
        # We also cannot dissolve the chain if the grandparent is root.
        while($node->deprel() =~ m/^(aux|cop)(:|$)/ && $node->parent()->deprel() =~ m/^(aux|cop)(:|$)/ && !$node->parent()->parent()->is_root())
        {
            $node->set_parent($node->parent()->parent());
        }
    }
}



#------------------------------------------------------------------------------
# Fixed expressions rarely have non-fixed children but if they do, then the
# children must be attached to the head of the fixed expression.
#------------------------------------------------------------------------------
sub raise_children_of_fixed
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # No need for recursion because there should not be chains of fixed relations.
        if($node->deprel() !~ m/^root(:|$)/ && $node->parent()->deprel() =~ m/^fixed(:|$)/)
        {
            $node->set_parent($node->parent()->parent());
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
                    # They probably fill a slot in the frame of the subordinate verb: 'nsubj', 'obj' etc.
                    if($mark->is_pronoun() && $mark->is_noun())
                    {
                        my $case = $mark->iset()->case();
                        if($case eq 'nom' || $case eq '')
                        {
                            $mark->set_deprel('nsubj');
                        }
                        else
                        {
                            $mark->set_deprel('obj');
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



#------------------------------------------------------------------------------
# Make sure that no node has more than one subject, except subjects subtyped as
# outer. If a nested clause acts as a nonverbal predicate, it is possible that
# both the outer and the inner subject will be attached to the same node, but
# then the outer subject must be subtyped as :outer.
#------------------------------------------------------------------------------
sub fix_multiple_subjects
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my @subjects = grep {$_->deprel() =~ m/subj/ && $_->deprel() !~ m/:outer/} ($node->get_children({'ordered' => 1}));
        for(my $i = 1; $i <= $#subjects; $i++)
        {
            $subjects[$i]->set_deprel('dep');
        }
    }
}



#------------------------------------------------------------------------------
# If a verb has an aux:pass or expl:pass child, its subject must be also *pass.
# We try to get the subjects right already during deprel conversion, checking
# whether the parent is a passive participle. But that will not work for
# reflexive passives, where we have to wait until the reflexive pronoun has its
# deprel. Probably it will also not work if the participle does not have the
# voice feature because its function is not limited to passive (such as in
# English). This method will fix it. It should be called after the main part of
# conversion is done (otherwise coordination could obscure the passive
# auxiliary).
#------------------------------------------------------------------------------
sub check_ncsubjpass_when_auxpass
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my @children = $node->children();
        my @auxpass = grep {$_->deprel() =~ m/^(aux|expl):pass$/} (@children);
        if(scalar(@auxpass) > 0)
        {
            foreach my $child (@children)
            {
                if($child->deprel() eq 'nsubj')
                {
                    $child->set_deprel('nsubj:pass');
                }
                elsif($child->deprel() eq 'csubj')
                {
                    $child->set_deprel('csubj:pass');
                }
                # Specific to some languages only: if the oblique agent is expressed, it is a bare instrumental noun phrase.
                # In the Prague-style annotation, it would be labeled as "obj" when we come here.
                elsif($child->deprel() eq 'obj' && $child->is_instrumental())
                {
                    $child->set_deprel('obl:agent');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Punctuation in coordination is sometimes attached to a non-head conjunction
# instead to the head (e.g. in Index Thomisticus). Now all coordinating
# conjunctions are attached to the first conjunct and so should be commas.
#------------------------------------------------------------------------------
sub raise_punctuation_from_coordinating_conjunction
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'punct')
        {
            my $parent = $node->parent();
            my $pdeprel = $parent->deprel() // '';
            if($pdeprel eq 'cc')
            {
                $node->set_parent($parent->parent());
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

=item Treex::Block::HamleDT::Udep

Converts dependency trees from the HamleDT/Prague style to the Universal
Dependencies. This block is experimental. In the future, it may be split into
smaller blocks, moved elsewhere in the inheritance hierarchy or otherwise
rewritten. It is also possible (actually quite likely) that the current
Harmonize* blocks will be modified to directly produce Universal Dependencies,
which will become our new default central annotation style.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::A2A::AddEnhancedUD;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'case'  => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'enhance oblique relation labels by case information' );
has 'coord' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'propagate shared parents and dependents across coordination' );
has 'xsubj' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'add relations to external subjects of open clausal complements' );
has 'relcl' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'transform relations between relative clauses and their modified nominals' );
has 'empty' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'add empty nodes where there are orphans in basic tree' );



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # We assume that the basic tree has been copied to the enhanced graph
    # (see the block A2A::CopyBasicToEnhanced). The enhanced graph is stored
    # in the wild attributes of nodes. Each node should now have the wild
    # attribute 'enhanced', which is a list of pairs, where each pair contains:
    # - the ord of the parent node
    # - the type of the relation between the parent node and this node
    # We do not store the Perl reference to the parent node in order to prevent cyclic references and issues with garbage collection.
    my @nodes = $root->get_descendants({'ordered' => 1});
    # First enhance all oblique relations with case information. If we later
    # copy those relations in other transformations, we want to be sure that
    # it all have been enhanced.
    if($self->case())
    {
        foreach my $node (@nodes)
        {
            if(!exists($node->wild()->{enhanced}))
            {
                log_fatal("The wild attribute 'enhanced' does not exist.");
            }
            $self->add_enhanced_case_deprel($node); # call this before coordination and relative clauses
        }
    }
    # Process all relations that shall be propagated across coordination before
    # proceeding to the next enhancement type.
    if($self->coord())
    {
        foreach my $node (@nodes)
        {
            $self->add_enhanced_parent_of_coordination($node);
            $self->add_enhanced_shared_dependent_of_coordination($node);
        }
    }
    # Add external subject relations in control verb constructions.
    if($self->xsubj())
    {
        my @visited_xsubj;
        foreach my $node (@nodes)
        {
            $self->add_enhanced_external_subject($node, \@visited_xsubj);
        }
    }
    # Process all relations affected by relative clauses before proceeding to
    # the next enhancement type. Calling this after the coordination enhancement
    # enables us to transform also coordinate relative clauses or modified nouns.
    if($self->relcl())
    {
        foreach my $node (@nodes)
        {
            $self->add_enhanced_relative_clause($node);
        }
        foreach my $node (@nodes)
        {
            $self->remove_enhanced_non_ref_relations($node);
        }
    }
    # Generate empty nodes instead of orphan relations.
    if($self->empty())
    {
        my %emptynodes;
        foreach my $node (@nodes)
        {
            $self->add_enhanced_empty_node($node, \%emptynodes);
        }
        ###!!! In the future we may want to directly generate this kind of empty nodes.
        ###!!! At present we keep the enhanced methods intact and convert the empty nodes when everything else has been done.
        $root->expand_empty_nodes();
    }
}



#------------------------------------------------------------------------------
# Adds case information to selected relation types. This function should be
# called before we propagate dependencies across coordination, as some of the
# labels that we enhance here will be later copied to new dependencies. For the
# same reason this function should be also called before adding relations back
# from a relative clause to the modified nominal. Interaction with gapping is
# less clear. The gapping-resolving algorithm will tell us that an orphan is
# "obl" or "advcl", but its case information may actually differ from that
# found at the overtly represented predicate.
#------------------------------------------------------------------------------
sub add_enhanced_case_deprel
{
    my $self = shift;
    my $node = shift;
    foreach my $edep (@{$node->wild()->{enhanced}})
    {
        my $eparent = $edep->[0];
        my $edeprel = $edep->[1];
        # We use paths to represent empty nodes in Treex, e.g., '0:root>34.1>cc'
        # means that there should be a root edge from 0 to 34.1, and a cc edge
        # from 34.1 to the actual node. If the graph already contains such edges,
        # do not touch them, we do not want to destroy them!
        next if($edeprel =~ m/>/);
        # The guidelines allow enhancing nmod, acl, obl and advcl.
        # If it makes sense in the language, core relations obj, iobj and ccomp can be enhanced too.
        # Sebastian's enhancer further enhances conj relations with the lemma of the conjunction, but it is not supported in the guidelines.
        next unless($edeprel =~ m/^(nmod|acl|obl|advcl)(:|$)/);
        # Collect case and mark children. We are modifying the enhanced deprel
        # but we look for input solely in the basic tree.
        ###!!! That means that we may not be able to find a preposition shared by conjuncts.
        ###!!! Finding it would need more work anyways, because we call this function before we propagate dependencies across coordination.
        my @children = $node->children({'ordered' => 1});
        my @casemark = grep {$_->deprel() =~ m/^(case|mark)(:|$)/} (@children);
        # If the current constituent is a clause, take mark dependents but not case dependents.
        # This may not work the same way in all languages, as e.g. in Swedish Joakim uses case even with clauses.
        # However, in Czech-PUD this will help us to skip prepositions under a nominal predicate, which modify the nominal but not the clause:
        # "kandidáta, který byl v pořadí za ním" ("candidate who was after him"): avoid the preposition "za"
        if($edeprel =~ m/^(acl|advcl)(:|$)/)
        {
            @casemark = grep {$_->deprel() !~ m/^case(:|$)/} (@casemark);
        }
        # For each of the markers check whether it heads a fixed expression.
        my @cmlemmas = grep {defined($_)} map
        {
            my $x = $_;
            my @fixed = grep {$_->deprel() =~ m/^(fixed)(:|$)/} ($x->children({'ordered' => 1}));
            my $l = lc($x->lemma());
            if(defined($l) && ($l eq '' || $l eq '_'))
            {
                $l = undef;
            }
            if(defined($l))
            {
                $l = lc($l);
                if(scalar(@fixed) > 0)
                {
                    $l .= '_' . join('_', map {lc($_->lemma())} (@fixed));
                }
            }
            $l;
        }
        (@casemark);
        my $cmlemmas = join('_', @cmlemmas);
        # Only selected characters are allowed in lemmas of case markers.
        # For example, digits and punctuation symbols (except underscore) are not allowed.
        $cmlemmas =~ s/[^\p{Ll}\p{Lm}\p{Lo}\p{M}_]//g;
        $cmlemmas =~ s/^_+//;
        $cmlemmas =~ s/_+$//;
        $cmlemmas =~ s/_+/_/g;
        $cmlemmas = undef if($cmlemmas eq '');
        if(defined($cmlemmas))
        {
            $edeprel .= ":$cmlemmas";
        }
        # Look for morphological case only if this is a nominal and not a clause.
        if($edeprel =~ m/^(nmod|obl)(:|$)/)
        {
            # In Slavic and some other languages, the case of a quantified phrase may
            # be determined by the quantifier rather than by the quantified head noun.
            # We can recognize such quantifiers by the relation nummod:gov or det:numgov.
            my @qgov = grep {$_->deprel() =~ m/^(nummod:gov|det:numgov)$/} (@children);
            my $qgov = scalar(@qgov);
            # There is probably just one quantifier. We do not have any special rule
            # for the possibility that there are more than one.
            my $caseiset = $qgov ? $qgov[0]->iset() : $node->iset();
            my $case = $caseiset->case();
            if(ref($case) eq 'ARRAY')
            {
                $case = $case->[0];
            }
            if(defined($case) && $case ne '')
            {
                $edeprel .= ':'.lc($case);
            }
        }
        # Store the modified enhanced deprel back to the wild attributes.
        $edep->[1] = $edeprel;
    }
}



#------------------------------------------------------------------------------
# Propagates parent of coordination to all conjuncts.
#------------------------------------------------------------------------------
sub add_enhanced_parent_of_coordination
{
    my $self = shift;
    my $node = shift;
    my @edeps = $node->get_enhanced_deps();
    if(any {$_->[1] =~ m/^conj(:|$)/} (@edeps))
    {
        my @edeps_to_propagate;
        # Find the nearest non-conj ancestor, i.e., the first conjunct.
        my @eparents = $node->get_enhanced_parents('^conj(:|$)');
        # There should be normally at most one conj parent for any node. So we take the first one and assume it is the only one.
        log_fatal("Did not find the 'conj' enhanced parent.") if(scalar(@eparents) == 0);
        my $inode = $eparents[0];
        while(defined($inode))
        {
            @eparents = $inode->get_enhanced_parents('^conj(:|$)');
            if(scalar(@eparents) == 0)
            {
                # There are no higher conj parents. So we will now look for the non-conj parents. Those are the relations we want to propagate.
                @edeps_to_propagate = grep {$_->[1] !~ m/^conj(:|$)/} ($inode->get_enhanced_deps());
                last;
            }
            $inode = $eparents[0];
        }
        if(defined($inode))
        {
            foreach my $edep (@edeps_to_propagate)
            {
                # Occasionally conjuncts differ in part of speech, meaning that their relation to the shared parent must differ, too.
                # Example [ru]: выполняться в произвольном порядке, параллельно или одновременно ("executed in arbitrary order, in parallel, or at the same time")
                # The first conjunct is a prepositional phrase and its relation is obl:в:loc(выполняться, порядке).
                # The other two conjuncts are adverbs, thus the relations should be advmod(выполняться, параллельно) and advmod(выполняться, одновременно).
                my $deprel = $edep->[1];
                if($deprel =~ m/^obl(:|$)/ && $node->is_adverb())
                {
                    $deprel = 'advmod';
                }
                elsif($deprel =~ m/^advmod(:|$)/ && $node->is_noun())
                {
                    ###!!! We should now also check whether a preposition or a case label should be added!
                    $deprel = 'obl';
                }
                $node->add_enhanced_dependency($node->get_node_by_ord($edep->[0]), $deprel);
                # The coordination may function as a shared dependent of other coordination.
                # In that case, make me depend on every conjunct in the parent coordination.
                if($inode->is_shared_modifier())
                {
                    my @conjuncts = $self->recursively_collect_conjuncts($node->get_node_by_ord($edep->[0]));
                    foreach my $conjunct (@conjuncts)
                    {
                        $node->add_enhanced_dependency($conjunct, $deprel);
                    }
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Propagates shared dependent of coordination to all conjuncts.
#------------------------------------------------------------------------------
sub add_enhanced_shared_dependent_of_coordination
{
    my $self = shift;
    my $node = shift;
    # Exclude shared "modifiers" whose deprel is 'cc'. They probably just help
    # delimit the coordination. (In nested coordination "A - B and C - D", the
    # conjunction 'and' would come out as a shared 'cc' dependent of 'C' and 'D'.)
    # Note: If the shared dependent itself is coordination, all conjuncts
    # should have the flag is_shared_modifier. (At least I have now checked
    # that there are nodes that have the flag and their deprel is 'conj'.
    # Of course that is not a proof that it happens always when it should.)
    # In that case, the parent is the first conjunct, and the effective parent
    # lies one or more levels further up. However, we solve this in the
    # function add_enhanced_parent_of_coordination(). Therefore, we do nothing
    # for non-first conjuncts in coordinate shared dependents here.
    if($node->is_shared_modifier())
    {
        # Get all suitable incoming enhanced relations.
        my @iedges = grep {$_->[1] !~ m/^(conj|cc|punct)(:|$)/} ($node->get_enhanced_deps());
        foreach my $iedge (@iedges)
        {
            my $parent = $node->get_node_by_ord($iedge->[0]);
            my $edeprel = $iedge->[1];
            my @conjuncts = $self->recursively_collect_conjuncts($parent);
            foreach my $conjunct (@conjuncts)
            {
                $node->add_enhanced_dependency($conjunct, $edeprel);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Returns the list of conj children of a given node. If there is nested
# coordination, returns the nested conjuncts too.
#------------------------------------------------------------------------------
sub recursively_collect_conjuncts
{
    my $self = shift;
    my $node = shift;
    my $visited = shift;
    # Keep track of visited nodes. Avoid endless loops.
    my @_dummy;
    if(!defined($visited))
    {
        $visited = \@_dummy;
    }
    return () if($visited->[$node->ord()]);
    $visited->[$node->ord()]++;
    my @echildren = $node->get_enhanced_children();
    my @conjuncts = grep {my $x = $_; any {$_->[0] == $node->ord() && $_->[1] =~ m/^conj(:|$)/} ($x->get_enhanced_deps())} (@echildren);
    my @conjuncts2;
    foreach my $c (@conjuncts)
    {
        my @c2 = $self->recursively_collect_conjuncts($c, $visited);
        if(scalar(@c2) > 0)
        {
            push(@conjuncts2, @c2);
        }
    }
    return (@conjuncts, @conjuncts2);
}



#------------------------------------------------------------------------------
# Looks for an external, grammatically coreferential subject of an open clausal
# complement (xcomp). Adds a subject relation if it finds it.
#
# Interactions with propagation of dependencies across coordination:
# If we do external subjects after coordination:
# * if the source argument for the subject is coordination (as in "John and
#   Mary wanted to do it"), by now we have a separate nsubj relation to each of
#   the conjuncts, and we can copy each of them as an xsubj.
# * if the control verb is coordination with a shared subject (as in "John
#   promised and succeeded to do it"), nothing new happens because we have the
#   xsubj relation from "do" to "John" anyway. However, if the conjuncts share
#   the xcomp but not the subject (as in "John promised and Mary succeeded to
#   do it"), we can now draw an xsubj from "do" to both "John" and "Mary".
# * if the controlled complement is coordination (as in "John promised to come
#   and clean up"), we can draw an xsubj from each of them.
# If we do external subjects before coordination:
# * an xsubj shared among coordinate xcomps could still be multiplied but only
#   if we mark it as a shared dependent when drawing the first xsubj.
# * coordinate control verbs with private control arguments will not propagate
# * coordinate control arguments will propagate via shared parent.
#
# Interactions with transformation of relative clauses:
# * žák, kterého chci přinutit naučit se počítat
#   (student whom I want to force to learn how to calculate)
# If we do relative clauses first
# * the controlled verb can point directly to the modified noun instead of the
#   relative pronoun. But it will not see that the relative pronoun was in the
#   accusative, hence it will not recognize the noun (which is in nominative)
#   as a suitable controller.
# If we do external subjects first
# * the xcomp infinitive will have the relative pronoun as its nsubj:xsubj.
#   A copy of this relation will be drawn to the noun, regardless of that the
#   parent is not the root of the relative clause.
#------------------------------------------------------------------------------
sub add_enhanced_external_subject
{
    my $self = shift;
    my $node = shift;
    my $visited = shift; # to avoid processing the same verb twice if we need to look at it early
    return if($visited->[$node->ord()]);
    $visited->[$node->ord()]++;
    # Are there any incoming xcomp edges?
    my @gverbs = $node->get_enhanced_parents('^xcomp(:|$)');
    return if(scalar(@gverbs) == 0);
    # The governing verb may itself be an infinitive controlled by another verb.
    # Make sure it is processed before myself, otherwise we may not be able to
    # reach to its enhanced subject.
    foreach my $gv (@gverbs)
    {
        $self->add_enhanced_external_subject($gv, $visited);
    }
    my ($nom, $dat, $acc) = $self->get_control_lemmas();
    my @nomcontrol = defined($nom) ? @{$nom} : ();
    my @datcontrol = defined($dat) ? @{$dat} : ();
    my @acccontrol = defined($acc) ? @{$acc} : ();
    foreach my $gv (@gverbs)
    {
        my $lemma = $gv->lemma();
        if(!defined($lemma))
        {
            my $form = $gv->form() // '';
            log_warn("Skipping control verb '$form' because its lemma is undefined.");
            next;
        }
        # Do we know the lemma and do we know which of its arguments should be coreferential with the subject of the infinitive?
        my $is_nomcontrol = any {$_ eq $lemma} (@nomcontrol);
        my $is_datcontrol = any {$_ eq $lemma} (@datcontrol);
        my $is_acccontrol = any {$_ eq $lemma} (@acccontrol);
        # Is this a subject-control verb?
        # Alternatively: is this an object-control verb in passive form?
        # Example [ru]: Компании вынуждены обращаться к системным интеграторам. ("Companies are forced to seek system integrators.")
        if($is_nomcontrol || $gv->iset()->is_passive() && $is_acccontrol)
        {
            # Does the control verb have an overt subject?
            my @subjects = $gv->get_enhanced_children('^[nc]subj(:|$)');
            foreach my $subject (@subjects)
            {
                my @edeps = grep {$_->[0] == $gv->ord() && $_->[1] =~ m/^[nc]subj(:|$)/} ($subject->get_enhanced_deps());
                if(scalar(@edeps) == 0)
                {
                    # This should not happen, as we explicitly asked for nodes that are in the subject relation.
                    log_fatal("Subject relation disappeared.");
                }
                elsif(scalar(@edeps) > 1)
                {
                    # This should not happen either, although it is not forbidden. But the same two nodes should not be connected simultaneously via nsubj, csubj, and/or nsubj:pass...
                    log_warn("Multiple subject relations between the same two nodes: ".join(', ', map {$_->[1]} (@edeps)));
                }
                my $edeprel = $edeps[0][1];
                # If the control verb is in passive form, its subject is [nc]subj:pass.
                # However, it should be an active subject of the controlled verb (see the Russian example above),
                # unless the controlled verb is also passive, as in [ru]:
                # Алгоритм может быть записан словами. ("An algorithm can be written in words.")
                ###!!! We rely on the VerbForm=Pass feature of the controlled verb.
                ###!!! This will work in Russian where we will see a passive participle.
                ###!!! But it may not work in other languages where the passive clause must be recognized by auxiliaries.
                unless($node->iset()->is_passive())
                {
                    $edeprel =~ s/:pass//;
                }
                # We could now add the ':xsubj' subtype to the relation label.
                # But we would first have to remove the previous subtype, if any.
                $subject->add_enhanced_dependency($node, $edeprel);
            }
        }
        # Is this a dative-control verb?
        elsif($is_datcontrol)
        {
            # Does the control verb have an overt dative argument?
            my @objects = $gv->get_enhanced_children('^(i?obj|obl:arg)(:|$)');
            # Select those arguments that are dative nominals without adpositions.
            @objects = grep
            {
                my $x = $_;
                my @casechildren = $x->get_enhanced_children('^case(:|$)');
                $x->is_dative() && scalar(@casechildren) == 0
            }
            (@objects);
            # If there are no dative objects, maybe there are reflexive dative expletives ("si").
            if(scalar(@objects) == 0)
            {
                my @expletives = grep {$_->is_dative() && $_->is_reflexive()} ($gv->get_enhanced_children('^expl(:|$)'));
                if(scalar(@expletives) > 0)
                {
                    # We will not mark coreference with the expletive. It is
                    # reflexive, so we have also a coreference with the subject;
                    # let's look for the subject then.
                    my @subjects = $gv->get_enhanced_children('^[nc]subj(:|$)');
                    @objects = @subjects;
                }
            }
            foreach my $object (@objects)
            {
                # Switch to 'nsubj:pass' if the controlled infinitive is passive.
                # Example: Zákon mu umožňuje být zvolen.
                my $edeprel = 'nsubj';
                if($node->iset()->is_passive() || scalar($node->get_enhanced_children('^(aux|expl):pass(:|$)')) > 0)
                {
                    $edeprel = 'nsubj:pass';
                }
                $object->add_enhanced_dependency($node, $edeprel);
            }
        }
        # Is this an accusative-control verb?
        elsif($is_acccontrol)
        {
            # Does the control verb have an overt accusative argument?
            my @objects = $gv->get_enhanced_children('^(i?obj|obl:arg)(:|$)');
            # Select those arguments that are accusative nominals without adpositions.
            @objects = grep
            {
                my $x = $_;
                my @casechildren = $x->get_enhanced_children('^case(:|$)');
                # In Slavic and some other languages, the case of a quantified phrase may
                # be determined by the quantifier rather than by the quantified head noun.
                # We can recognize such quantifiers by the relation nummod:gov or det:numgov.
                my @qgov = $x->get_enhanced_children('^(nummod:gov|det:numgov)$');
                my $qgov = scalar(@qgov);
                # There is probably just one quantifier. We do not have any special rule
                # for the possibility that there are more than one.
                my $caseiset = $qgov ? $qgov[0]->iset() : $x->iset();
                $caseiset->is_accusative() && scalar(@casechildren) == 0
            }
            (@objects);
            # If there are no accusative objects, maybe there are reflexive accusative expletives ("se").
            if(scalar(@objects) == 0)
            {
                my @expletives = grep {$_->is_accusative() && $_->is_reflexive()} ($gv->get_enhanced_children('^expl(:|$)'));
                if(scalar(@expletives) > 0)
                {
                    # We will not mark coreference with the expletive. It is
                    # reflexive, so we have also a coreference with the subject;
                    # let's look for the subject then.
                    my @subjects = $gv->get_enhanced_children('^[nc]subj(:|$)');
                    @objects = @subjects;
                }
            }
            foreach my $object (@objects)
            {
                # Switch to 'nsubj:pass' if the controlled infinitive is passive.
                # Example: Zákon ho opravňuje být zvolen.
                my $edeprel = 'nsubj';
                if($node->iset()->is_passive() || scalar($node->get_enhanced_children('^(aux|expl):pass(:|$)')) > 0)
                {
                    $edeprel = 'nsubj:pass';
                }
                $object->add_enhanced_dependency($node, $edeprel);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Transforms the enhanced dependencies between a relative clause, its
# relativizer, and the modified noun.
#
# Interactions with propagation of dependencies across coordination:
# If we do relative clauses before coordination:
# * coordinate parent nominals: new incoming (nsubj/obj/...) and outgoing (ref)
#   edges will be later propagated to/from the other conjuncts. We actually
#   do not know whether the relative clause is shared among the conjuncts. If
#   it is, then we should mark the relevant nodes as shared dependents.
# * coordinate relative clauses: the second clause does not know it is a
#   relative clause, so it does nothing.
# If we do relative clauses after coordination:
# * if the relative clause is shared among coordinate parent nominals, by now
#   we have a separate acl:relcl dependency to each of them. And if we actually
#   look at the enhanced graph, we will get all the transformations.
# * coordinate relative clauses: we could transform each of them and the parent
#   nominal could even have a different function in each of them. If they share
#   the relativizer, we could see it as well.
#------------------------------------------------------------------------------
sub add_enhanced_relative_clause
{
    my $self = shift;
    my $node = shift;
    # This node is the root of a relative clause if at least one of its parents
    # is connected via the acl:relcl relation. We refer to the parent of the
    # clause as the modified $noun, although it may be a pronoun.
    my @nouns = $node->get_enhanced_parents('^acl:relcl(:|$)');
    return if(scalar(@nouns)==0);
    # Tamil relative clauses do not contain overt relative pronouns, so we
    # cannot use them to determine the relation and we cannot reattach them
    # via the 'ref' relation. However, we still can add the cyclic relation
    # from the head of the relative clause to the noun (the relation is always
    # subject). For all other languages we will not do anything if we have not
    # found a relativizer.
    if($self->language() eq 'ta')
    {
        foreach my $noun (@nouns)
        {
            # Add a subject relation between the relative participle and the modified noun.
            $self->add_enhanced_dependency($noun, $node, 'nsubj');
        }
    }
    else # not Tamil
    {
        # If there are coordinate relative clauses, we may have already added a
        # cycle, meaning that the modified noun is now also a descendant of the
        # relative clause. However, we do not want to traverse it when looking for
        # the relativizer! Hence we mark it as visited before collecting the
        # descendants.
        # Example:
        # máme povědomí, jaké to bude těleso, se kterým by se Země mohla či měla srazit
        # The noun is "těleso", the coordinate relative clauses are headed by
        # "mohla" and "měla", and the unwanted relativizer is "jaké", attached to
        # "těleso" (the correct relativizer is "kterým" and it is shared by both
        # relative clauses).
        my @visited; map {$visited[$_->ord()]++} (@nouns);
        my @relativizers = sort {$a->ord() <=> $b->ord()}
        (
            grep {$_->ord() <= $node->ord() && $_->is_relative()}
            (
                $node,
                $self->get_enhanced_descendants($node, \@visited)
            )
        );
        return unless(scalar(@relativizers) > 0);
        ###!!! Assume that the leftmost relativizer is the one that relates to the
        ###!!! current relative clause. This is an Indo-European bias.
        my $relativizer = $relativizers[0];
        my @edeps = $self->get_enhanced_deps($relativizer);
        # All relations other than 'ref' will be copied to the noun.
        # Besides 'ref', we should also exclude any collapsed paths over empty nodes
        # (unless we can give them the special treatment they need). This is because
        # there may be a second relative clause as a gapped conjunct, and the collapsed
        # edge may lead back to the noun. An instance of this occurs in the Latvian
        # LVTB training data, sent_id = a-p13850-p28s2:
        # "personas, kura nebūtu saistīta ar pārējām un arī ar putnu"
        # "a person which is unrelated to the rest and also to the bird"
        # The first relative clause:
        #   acl:relcl(personas, saistīta)
        #   nsubj(saistīta, kura)
        #   iobj(saistīta, pārējām)
        # The second relative clause uses an empty node with the id 37.1 for a copy of saistīta:
        #   acl>37.1>nsubj(personas, kura)
        #   acl>37.1>iobj(personas, putnu)
        ###!!! We now avoid creating a cycle when processing this Latvian sentence.
        ###!!! But we do not transform the second relative clause correctly.
        ###!!! Either the self-loops should be allowed in such cases, or the entire
        ###!!! mechanism for empty nodes in Treex must be rewritten and real Node
        ###!!! objects must be used.
        my @noundeps = grep {$_->[1] ne 'ref' && $_->[1] !~ m/>/} (@edeps);
        foreach my $noun (@nouns)
        {
            # Add an enhanced relation 'ref' from the modified noun to the relativizer.
            $self->add_enhanced_dependency($relativizer, $noun, 'ref');
            # If the relativizer is the root of the relative clause, there is no other
            # node in the relative clause from which a new relation should go to the
            # modified noun. However, the relative clause has a nominal predicate,
            # which corefers with the modified noun, and we can draw a new relation
            # from the modified noun to the subject of the relative clause.
            if($relativizer == $node)
            {
                my @subjects = grep {$_->deprel() =~ m/^[nc]subj(:|$)/} ($node->children());
                foreach my $subject (@subjects)
                {
                    $self->add_enhanced_dependency($subject, $noun, $subject->deprel());
                }
            }
            # If the relativizer is not the root of the relative clause, we remove its
            # current relation to its current parent and instead we add an analogous
            # relation between the parent and the modified noun.
            else
            {
                foreach my $nd (@noundeps)
                {
                    my $relparent = $nd->[0];
                    my $reldeprel = $nd->[1];
                    # Although the the current node (root of the relative clause)
                    # is not the relativizer, the possibility of self-loops is not
                    # excluded. In the Finnish TDT training sentence f102.5, there
                    # is coordination of relative clauses, the first clause is
                    # headed by the relativizer, which at the same time acts as
                    # an oblique argument in the second and the third clause. When
                    # we process it from the perspective of the second clause (where it is not the root),
                    # we will also see the acl:relcl relation that connects it to
                    # the modified noun. We must ignore this relation, otherwise it
                    # will lead to a self-loop.
                    # Niitä, joilla on farmariautot sekä kultainennoutaja kopissaan, lapset huutavat ja kiirettä tuntuu olevan kokoajan arjen keskellä.
                    # Google Translate: Children with station wagons and a golden retriever in their booths are screaming and hurrying in the midst of everyday life.
                    # Niitä = those (partitive demonstrative) is the root of the sentence.
                    # First clause: joilla on farmariautot sekä kultainennoutaja kopissaan = with station wagons and a golden retriever in their booth (joilla = whose = the head and the relativizer)
                    # Second clause: lapset huutavat = the children cry (joilla is oblique argument of this)
                    # Third clause: ja kiirettä tuntuu olevan kokoajan arjen keskellä (joilla oblique here too) = and hurry seems to be in the middle of everyday life
                    # I.e.: those, whose are station wagons, whose children cry and who feel in a hurry
                    my $relparentnode = $self->get_node_by_ord($node, $relparent);
                    next if($relparentnode == $noun);
                    # Even if the relativizer is adverb or determiner, the new dependent will be noun or pronoun.
                    # Discard subtypes of the original relation, if present. Such subtypes may not be available
                    # for the substitute relation.
                    $reldeprel =~ s/^advmod(:.+)?$/obl/;
                    $reldeprel =~ s/^det(:.+)?$/nmod/;
                    $self->add_enhanced_dependency($noun, $relparentnode, $reldeprel);
                }
            }
        }
    }
    # We have to wait with removing the non-ref relations until all relative
    # clauses in the sentence have been processed, so it will be done in a
    # separate function.
}



#------------------------------------------------------------------------------
# Removes non-ref incoming edges of all relativizers except those that are
# heads of their relative clauses. We must do this after all edges from all
# relative clauses to their nouns have been added. If we do this earlier and
# if a relativizer is shared among coordinate relative clauses (or coordinate
# modified nouns), we will not be able to find the relativizer from the other
# relative clauses.
#------------------------------------------------------------------------------
sub remove_enhanced_non_ref_relations
{
    my $self = shift;
    my $node = shift;
    # Only do this to relativizers. Every relativizer has at least one incoming
    # ref edge by now.
    my @edeps = $node->get_enhanced_deps();
    return if(!any {$_->[1] =~ m/^ref(:|$)/} (@edeps));
    # Do not do this to relativizers that are heads of their relative clauses,
    # i.e., they also have an acl:relcl incoming edge.
    return if(any {$_->[1] =~ m/^acl:relcl(:|$)/} (@edeps));
    my @reldeps = grep {$_->[1] =~ m/^ref(:|$)/} (@edeps);
    $node->wild()->{enhanced} = \@reldeps;
}



#------------------------------------------------------------------------------
# Transforms gapping constructions to structures with empty nodes. The a-layer
# in Treex does not really support empty nodes so we will model them using
# concatenations of incoming and outgoing edges. For example, suppose that
# an empty node should have position 5.1, that it has one conj parent X, one
# nsubj child Y and one obj child Z. Then we will draw an edge from X to Y and
# label it "conj>5.1>nsubj", and an edge from X to Z labeled "conj>5.1>obj".
# We will assume that the block Write::CoNLLU is able to use this information
# to produce the desired CoNLL-U representation of the graph with empty nodes.
#------------------------------------------------------------------------------
sub add_enhanced_empty_node
{
    my $self = shift;
    my $node = shift;
    my $emptynodes = shift; # hash ref, keys are ids of empty nodes
    # We have to generate an empty node if a node has one or more orphan children.
    my @orphans = $node->get_enhanced_children('^orphan(:|$)');
    return if(scalar(@orphans) == 0);
    my $emppos = $self->get_empty_node_position($node, $emptynodes);
    $emptynodes->{$emppos}++;
    # All current parents of $node will become parents of the empty node.
    ###!!! There should not be any 'orphan' among the relations to the parents.
    ###!!! If there is one, we should process the parent first. However, for now
    ###!!! we simply ignore the 'orphan' and change it to 'dep'.
    my @origiedges = $node->get_enhanced_deps();
    foreach my $ie (@origiedges)
    {
        $ie->[1] =~ s/^orphan(:|$)/dep$1/;
    }
    # Create the paths to $node via the empty node. We do not know what the
    # relation between the empty node and $node should be. We just use 'dep'
    # for now, unless the node is an adverb, when it is probably safe to say
    # that it is 'advmod'.
    my %nodeiedges;
    my $cdeprel = $node->is_adverb() ? 'advmod' : 'dep';
    foreach my $ie (@origiedges)
    {
        $nodeiedges{$ie->[0]}{$ie->[1].">$emppos>".$cdeprel}++;
    }
    my @nodeiedges;
    foreach my $pord (sort {$a <=> $b} (keys(%nodeiedges)))
    {
        foreach my $edeprel (sort {$a cmp $b} (keys(%{$nodeiedges{$pord}})))
        {
            push(@nodeiedges, [$pord, $edeprel]);
        }
    }
    $node->wild()->{enhanced} = \@nodeiedges;
    # Create the path to each child via the empty node. Also use just 'dep' for
    # now, unless the node is an adverb, when it is probably safe to say
    # that it is 'advmod'.
    my @children = $node->get_enhanced_children();
    foreach my $child (@children)
    {
        my @origchildiedges = $child->get_enhanced_deps();
        my %childiedges;
        my $ccdeprel = $child->is_adverb() ? 'advmod' : 'dep';
        foreach my $cie (@origchildiedges)
        {
            if($cie->[0] == $node->ord())
            {
                foreach my $pie (@origiedges)
                {
                    my $cdeprel = $cie->[1];
                    # Only redirect selected relations via the empty node:
                    # orphan, cc, mark, punct. Keep the others (in particular
                    # nominal modifiers) attached directly to $node.
                    if($cdeprel =~ m/^(orphan|cc|mark|punct)(:|$)/)
                    {
                        $cdeprel =~ s/^orphan(:.+)?$/$ccdeprel/;
                        $childiedges{$pie->[0]}{$pie->[1].">$emppos>".$cdeprel}++;
                    }
                    else
                    {
                        $childiedges{$cie->[0]}{$cie->[1]}++;
                    }
                }
            }
            else
            {
                $childiedges{$cie->[0]}{$cie->[1]}++;
            }
        }
        my @childiedges;
        foreach my $pord (sort {$a <=> $b} (keys(%childiedges)))
        {
            foreach my $edeprel (sort {$a cmp $b} (keys(%{$childiedges{$pord}})))
            {
                push(@childiedges, [$pord, $edeprel]);
            }
        }
        $child->wild()->{enhanced} = \@childiedges;
    }
}



#------------------------------------------------------------------------------
# Determines position for a new empty node.
# For the moment we will position the empty node right before its first child.
# Exception: if this is a non-first conjunct and the first child is shared
# and appears before the first conjunct, skip it. We do not want to place the
# second conjunct before the first one (conj relation must go left-to-right).
# There might be better heuristics but the position does not matter much.
# However, we must not pick a position that is already taken by another
# empty node. For that we need the hash of all empty nodes generated in this
# sentence so far.
#------------------------------------------------------------------------------
sub get_empty_node_position
{
    my $self = shift;
    my $node = shift; # node to be replaced by the empty node and to become a child of the empty node
    my $emptynodes = shift; # hash ref, keys are ids of existing empty nodes
    # The current node and all its current children will become children of the
    # empty node.
    my @children = $node->get_enhanced_children();
    my @empchildren = sort {$a->ord() <=> $b->ord()} ($node, @children);
    my $posmajor = $empchildren[0]->ord() - 1;
    my $posminor = 1;
    # If the current node is a conj child of another node, discard children that
    # occur before that other node.
    my @conjparents = sort {$a->ord() <=> $b->ord()} ($node->get_enhanced_parents('^conj(:|$)'));
    if(scalar(@conjparents) > 0)
    {
        @empchildren = grep {$_->ord() > $conjparents[-1]->ord()} (@empchildren);
        if(scalar(@empchildren) > 0)
        {
            $posmajor = $empchildren[0]->ord() - 1;
        }
        # The else branch should not be needed because at least $node should be
        # located after all its conj parents. But there is no guarantee that the
        # basic annotation is correct.
        else
        {
            $posmajor = $conjparents[-1]->ord();
        }
    }
    while(exists($emptynodes->{"$posmajor.$posminor"}))
    {
        $posminor++;
    }
    my $emppos = "$posmajor.$posminor";
    return $emppos;
}



#==============================================================================
# Helper functions for manipulation of the enhanced graph.
#==============================================================================



#------------------------------------------------------------------------------
# Returns the relation from a node to parent with ord N. Returns the first
# relation if there are multiple relations to the same parent (this method is
# intended only for situations where we are confident that there is exactly one
# such relation). Throws an exception if the wild attribute 'enhanced' does not
# exist or if there is no relation to the given parent.
#------------------------------------------------------------------------------
sub get_first_edeprel_to_parent_n
{
    my $self = shift;
    my $node = shift;
    my $parentord = shift;
    my @edeps = $node->get_enhanced_deps();
    my @edges_from_n = grep {$_->[0] == $parentord} (@edeps);
    if(scalar(@edges_from_n) == 0)
    {
        log_fatal("No relation to parent with ord '$parentord' found.");
    }
    return $edges_from_n[0][1];
}



#==============================================================================
# Language-specific lists of lemmas.
#==============================================================================



#------------------------------------------------------------------------------
# Returns the language-specific list of lemmas (typically verbs, but some of
# them are adjectives) that control their open complements (typically
# infinitives): the subject of the infinitive is coreferential with a
# particular argument of the controlling verb.
#------------------------------------------------------------------------------
sub get_control_lemmas
{
    my $self = shift;
    my $language = $self->language();
    # nom: verbs whose subject (nominative argument) is coreferential with the subject of xcomp
    # dat: verbs whose dative argument is coreferential with the subject of xcomp
    # acc: verbs whose accusative argument (object) is coreferential with the subject of xcomp
    my %control; # $control{language}{nom} = \@nomcontrol;
    # Subject / nominative argument control.
    # Modality / external circumstances:
    push(@{$control{cs}{nom}}, qw(moci mít muset musit smět potřebovat));
    push(@{$control{sk}{nom}}, qw(môcť mať musieť smieť potrebovať));
    push(@{$control{pl}{nom}}, qw(móc można mieć winien powinien musieć potrzebować));
    # Note: должен is ADJ, not VERB, but otherwise it should work the same way.
    push(@{$control{ru}{nom}}, qw(мочь должен требовать));
    push(@{$control{lt}{nom}}, qw(galėti turėti reikėti privalėti tekti));
    # Modality / will of the actor:
    # Weak positive:
    push(@{$control{cs}{nom}}, qw(chtít hodlat mínit plánovat zamýšlet toužit troufnout troufat odvážit odvažovat odhodlat odhodlávat zvyknout zvykat));
    push(@{$control{sk}{nom}}, qw(chcieť hodlať mieniť plánovať zamýšľať túžiť želať trúfnuť trúfať odvážiť odvažovať odhodlať odhodlávať));
    push(@{$control{pl}{nom}}, qw(chcieć zechcieć zamierzać myśleć pomyśleć planować deliberować woleć pragnąć marzyć śnić śmieć ośmielić odważyć lubić));
    # Warning: желать can control either nominative or, if present, dative.
    push(@{$control{ru}{nom}}, qw(хотеть захотеть планировать намереваться рассчитывать предпочесть предпочитать надеяться думать задумать придумать мечтать счесть сметь любить привыкнуть));
    push(@{$control{lt}{nom}}, qw(siekti norėti norėtis planuoti ketinti numatyti mėgti));
    # Strong positive:
    push(@{$control{cs}{nom}}, qw(rozhodnout rozhodovat zavázat zavazovat přislíbit slíbit slibovat));
    push(@{$control{sk}{nom}}, qw(rozhodnúť rozhodovať zaviazať zaväzovať prisľúbiť sľúbiť sľubovať));
    push(@{$control{pl}{nom}}, qw(postanowić postanawiać decydować zdecydować obiecać obiecywać ślubować zgodzić));
    push(@{$control{ru}{nom}}, qw(решить решать решиться решаться собраться обещать пообещать согласиться договориться гарантировать));
    push(@{$control{lt}{nom}}, qw(nuspręsti));
    # Strong negative:
    push(@{$control{cs}{nom}}, qw(odmítnout odmítat));
    push(@{$control{sk}{nom}}, qw(odmietnuť odmietať));
    push(@{$control{ru}{nom}}, qw(отказаться отказываться));
    # Weak negative:
    push(@{$control{cs}{nom}}, qw(bát obávat stydět zdráhat ostýchat rozmyslit rozpakovat váhat));
    push(@{$control{sk}{nom}}, qw(báť obávať hanbiť zdráhať ostýchať rozmyslieť rozpakovať váhať));
    push(@{$control{pl}{nom}}, qw(obawiać));
    push(@{$control{ru}{nom}}, qw(бояться));
    push(@{$control{lt}{nom}}, qw(atsisakyti bijoti));
    # Passive negative:
    push(@{$control{cs}{nom}}, qw(zapomenout zapomínat opomenout opomíjet));
    push(@{$control{sk}{nom}}, qw(zabudnúť zabúdať opomenúť));
    push(@{$control{pl}{nom}}, qw(zapomnieć omieszkać));
    push(@{$control{ru}{nom}}, qw(забыть забывать));
    # Ability:
    push(@{$control{cs}{nom}}, qw(umět dokázat dovést snažit namáhat usilovat pokusit pokoušet zkusit zkoušet stačit stihnout stíhat zvládnout zvládat));
    push(@{$control{sk}{nom}}, qw(vedieť dokázať doviesť snažiť namáhať usilovať pokúsiť pokúšať skúsiť skúšať stačiť stihnúť stíhať zvládnuť vládať));
    push(@{$control{pl}{nom}}, qw(umieć wiedzieć potrafić zdążyć zdołać starać postarać usiłować próbować spróbować));
    push(@{$control{ru}{nom}}, qw(уметь знать успеть успевать пытаться стремиться стараться браться норовить затрудниться пробовать учиться научиться));
    push(@{$control{lt}{nom}}, qw(bandyti pabandyti stengtis mėginti pasistengti sugebėti išmokti mokytis pavykti));
    # Aspect and phase:
    push(@{$control{cs}{nom}}, qw(chystat začít začínat jmout počít počínat zůstat vydržet přestat přestávat končit skončit));
    push(@{$control{sk}{nom}}, qw(chystať začať začínať počať počínať zostať ostať vytrvať prestať prestávať končiť skončiť));
    push(@{$control{pl}{nom}}, qw(zacząć zaczynać jąć począć poczynać pozostawać przestać przestawać kończyć skończyć powstrzymywać));
    push(@{$control{ru}{nom}}, qw(собираться готовиться начать начинать приняться продолжить продолжать остаться оставаться уставать перестать переставать прекратить));
    push(@{$control{lt}{nom}}, qw(pradėti belikti telikti));
    # Movement (to go somewhere to do something):
    push(@{$control{cs}{nom}}, qw(jít chodit utíkat spěchat jet jezdit odejít odcházet odjet odjíždět přijít přicházet přijet přijíždět));
    push(@{$control{sk}{nom}}, qw(ísť chodiť utekať ponáhľať jet jazdiť odísť odchádzať prísť přichádzať));
    push(@{$control{pl}{nom}}, qw(iść pójść chodzić jechać przyjść przychodzić wydawać));
    push(@{$control{ru}{nom}}, qw(пойти идти ездить отправиться спешить торопиться прийти приходить приехать));
    # Other action than movement:
    push(@{$control{cs}{nom}}, qw(vzít)); # vzít si za úkol
    push(@{$control{sk}{nom}}, qw(vziať)); # vzít si za úkol
    push(@{$control{pl}{nom}}, qw(kłaść));
    push(@{$control{ru}{nom}}, qw(догадаться));
    push(@{$control{lt}{nom}}, qw(imti));
    # Attitude or perspective of the speaker:
    push(@{$control{cs}{nom}}, qw(zdát hrozit ráčit));
    push(@{$control{sk}{nom}}, qw(zdať hroziť ráčiť));
    push(@{$control{pl}{nom}}, qw(zdawać raczyć));
    push(@{$control{ru}{nom}}, qw(рискнуть рисковать грозить));
    push(@{$control{lt}{nom}}, qw(rizikuoti));
    # Pseudocopulas: (not "znamenat" / "znamenať" / "значить", there is no coreference!)
    push(@{$control{cs}{nom}}, qw(působit pracovat cítit ukazovat ukázat));
    push(@{$control{sk}{nom}}, qw(pôsobiť pracovať cítiť ukazovať ukázať));
    push(@{$control{ru}{nom}}, qw(стать считать));
    # Dative argument control.
    # Enabling:
    push(@{$control{cs}{dat}}, qw(umožnit umožňovat dovolit dovolovat povolit povolovat dát dávat příslušet));
    push(@{$control{sk}{dat}}, qw(umožniť umožňovať dovoliť dovoľovať povoliť povoľovať dať dávať prináležať));
    push(@{$control{pl}{dat}}, qw(dozwolić pozwolić pozwalać dać dawać należeć pozostawać));
    push(@{$control{ru}{dat}}, qw(разрешить разрешать позволить позволять напозволять дать давать доверить доверять предоставить предоставлять));
    push(@{$control{lt}{dat}}, qw(leisti));
    # Modality / will of the actor:
    push(@{$control{ru}{dat}}, qw(хотеться захотеться быть прийтись));
    # Recommendation:
    push(@{$control{cs}{dat}}, qw(doporučit doporučovat navrhnout navrhovat poradit radit));
    push(@{$control{sk}{dat}}, qw(odporučiť odporúčať navrhnúť navrhovať poradiť radiť hovoriť povedať pobádať));
    push(@{$control{pl}{dat}}, qw(polecić zalecać proponować radzić));
    push(@{$control{ru}{dat}}, qw(рекомендовать предложить предлагать советовать посоветовать сказать подсказать подсказывать));
    push(@{$control{lt}{dat}}, qw(siūlyti pasiūlyti patarti raginti rekomenduoti));
    # Order:
    push(@{$control{cs}{dat}}, qw(uložit ukládat přikázat přikazovat nařídit nařizovat velet klást kázat));
    push(@{$control{sk}{dat}}, qw(uložiť ukladať prikázať prikazovať nariadiť nariaďovať veliť klásť kázať));
    push(@{$control{pl}{dat}}, qw(rozkazać rozkazować nakazać nakazywać kazać));
    push(@{$control{ru}{dat}}, qw(задать задавать приказать приказывать поручить поручать командовать велеть предписать заказать наказать));
    # Negative order, disabling:
    push(@{$control{cs}{dat}}, qw(bránit zabránit zabraňovat znemožnit znemožňovat zakázat zakazovat zapovědět zapovídat));
    push(@{$control{sk}{dat}}, qw(brániť zabrániť zabraňovať znemožniť znemožňovať zakázať zakazovať));
    push(@{$control{pl}{dat}}, qw(szkodzić przeszkadzać));
    push(@{$control{ru}{dat}}, qw(мешать запретить запрещать препятствовать));
    # Success:
    push(@{$control{cs}{dat}}, qw(podařit dařit));
    push(@{$control{sk}{dat}}, qw(podariť dariť postačiť));
    push(@{$control{pl}{dat}}, qw(udać udawać zdążyć zdarzać opłacać wypadać));
    push(@{$control{ru}{dat}}, qw(удаться));
    # Object / accusative argument control.
    # Enabling or request:
    push(@{$control{cs}{acc}}, qw(oprávnit opravňovat zmocnit zmocňovat prosit poprosit pustit));
    push(@{$control{sk}{acc}}, qw(oprávniť opravňovať zmocniť zmocňovať prosiť poprosiť pustiť));
    push(@{$control{ru}{acc}}, qw(просить попросить призвать призывать звать пригласить приглашать заклинать));
    push(@{$control{lt}{acc}}, qw(prašyti paprašyti));
    # Order, enforcement, encouragement:
    push(@{$control{cs}{acc}}, qw(donutit přinutit nutit přimět zavázat zavazovat pověřit pověřovat přesvědčit přesvědčovat odsoudit odsuzovat));
    push(@{$control{sk}{acc}}, qw(donútiť prinútiť nútiť zaviazať zaväzovať poveriť poverovať presvedčiť presviedčať odsúdiť odsudzovať));
    push(@{$control{ru}{acc}}, qw(вынудить вынуждать понуждать принудить принуждать заставить заставлять побудить побуждать поручить поручать убедить убеждать уговаривать обязать обязывать стимулировать вдохновить вдохновлять мотивировать подвинуть поощрять провоцировать тянуть уговорить));
    push(@{$control{lt}{acc}}, qw(priversti));
    # Teaching:
    push(@{$control{cs}{acc}}, qw(učit naučit odnaučit odnaučovat));
    push(@{$control{sk}{acc}}, qw(učiť naučiť odnaučiť odučovať));
    push(@{$control{pl}{acc}}, qw(uczyć nauczyć));
    push(@{$control{ru}{acc}}, qw(учить научить обучить обучать отучить отучать));
    push(@{$control{lt}{acc}}, qw(mokyti));
    # Movement (to send somebody somewhere to do something):
    push(@{$control{ru}{acc}}, qw(отправить отправлять послать отослать присылать брать));
    # Seeing (viděl umírat lidi):
    push(@{$control{cs}{acc}}, qw(vidět));
    push(@{$control{sk}{acc}}, qw(vidieť));
    push(@{$control{pl}{acc}}, qw(widzieć));
    push(@{$control{ru}{acc}}, qw(видеть));
    # Pseudocopulas:
    push(@{$control{cs}{acc}}, qw(činit učinit));
    push(@{$control{sk}{acc}}, qw(činiť urobiť));

    # Uralic languages.
    # Subject / nominative argument control.
    # Modality / external circumstances:
    # pystyä = can
    push(@{$control{fi}{nom}}, qw(pystyä));
    # suutma = can; pruukima = need
    push(@{$control{et}{nom}}, qw(suutma pruukima));
    # Modality / will of the actor:
    # Weak positive:
    # haluta = want; kiinnostua = be interested in; tarjoutua = offer
    push(@{$control{fi}{nom}}, qw(haluta kiinnostua tarjoutua));
    # tahtma = want; julgema = dare; soovima = wish; kavatsema = plan;
    # lootma = hope; pakkuma = offer; söandama = dare
    push(@{$control{et}{nom}}, qw(tahtma julgema soovima kavatsema lootma pakkuma söandama));
    # Strong positive:
    # päättää = decide; luvata = promise; suostua = agree
    push(@{$control{fi}{nom}}, qw(päättää luvata suostua));
    # otsustama = decide
    push(@{$control{et}{nom}}, qw(otsustama));
    # Strong negative:
    # kieltäytyä = refuse
    push(@{$control{fi}{nom}}, qw(kieltäytyä));
    # keelduma = refuse
    push(@{$control{et}{nom}}, qw(keelduma));
    # Weak negative:
    # epäröidä = hesitate
    push(@{$control{fi}{nom}}, qw(epäröidä));
    # jaksama = endure; kannatama = suffer; kartma = fear; muretsema = worry
    push(@{$control{et}{nom}}, qw(jaksama kannatama kartma muretsema));
    # Ability:
    # onnistua = succeed; yrittää = try; koettaa = try; pyrkiä = strive;
    # osata = know, master
    push(@{$control{fi}{nom}}, qw(onnistua yrittää koettaa pyrkiä osata));
    # oskama = know how; püüdma = strive; üritama = try; proovima = try;
    # katsuma = attempt
    push(@{$control{et}{nom}}, qw(oskama püüdma üritama proovima katsuma));
    # Aspect and phase:
    # alkaa = begin; keskittyä = attend, settle down; koittaa = break;
    # päätyä = end up, finish up
    push(@{$control{fi}{nom}}, qw(alkaa keskittyä koittaa päätyä));
    # algama = begin
    push(@{$control{et}{nom}}, qw(algama));
    # Other action than movement:
    # kiirehtiä = rush; palata = return, revive
    push(@{$control{fi}{nom}}, qw(kiirehtiä palata));
    # kiirustama = rush
    push(@{$control{et}{nom}}, qw(kiirustama));
    # Attitude of the speaker:
    # viitsiä = bother
    push(@{$control{fi}{nom}}, qw(viitsiä));
    # viitsima = bother; suvatsema = deign
    push(@{$control{et}{nom}}, qw(viitsima suvatsema));

    # Other Finnish verbs that have been observed governing an xcomp and not governing an obj.
    # Note that this does not imply that their subject controls the open complement (infinitive).
    # The open complement can be controlled by an oblique argument rather than object.
    # saada = get have make obtain
    # tulla = become come get arrive
    # auttaa = help assist aid
    # antaa = give let issue deliver
    # kannustaa = encourage urge stimulate
    # käydä = visit call go run
    # käyttää = use exercise wear operate
    # pakottaa = force drive compel oblige
    # asettaa = set lay position place
    # estää = prevent preclude forestall inhibit
    # kehittää = develop evolve improve elaborate
    # kehottaa = urge recommend invite advise
    # kieltää = prohibit forbid
    # lähettää = send broadcast post transmit
    # laittaa = put lay set fix
    # olla = be exist have hold
    # pyytää = request ask demand seek
    # sallia = allow permit let tolerate
    # suositella = recommend commend
    # työskennellä = work
    # varoittaa = warn caution dissuade

    # Other Estonian verbs that have been observed governing an xcomp and not governing an obj.
    # Note that this does not imply that their subject controls the open complement (infinitive).
    # The open complement can be controlled by an oblique argument (adessive) rather than object.
    # aitama = help assist aid
    # soovitama = recommend commend suggest
    # laskma = have let allow
    # paluma = ask pray beg
    # lubama = allow permit let authorize
    # saama = receive become get acquire
    # tegema = do perform make execute
    # võimaldama = enable allow permit
    # andma = give grant yield allow
    # jõudma = reach arrive come get
    # käskima = command order tell
    # keelama = prohibit forbid ban
    # olenema = depend turn
    # võtma = admit

    return ($control{$language}{nom}, $control{$language}{dat}, $control{$language}{acc});
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::AddEnhancedUD

=head1 DESCRIPTION

In Universal Dependencies, there is basic and enhanced representation. The
basic representation is a tree and corresponds to the a-tree in Treex. The
enhanced representation is a directed graph and can be optionally stored in
wild attributes of individual nodes (there is currently no API for the
enhanced structure).

This block adds the enhancements defined in the UD v2 guidelines based on the
basic dependencies. The block must be called after the basic dependencies have
been copied to the enhanced graph (see the block CopyBasicToEnhancedUD). It is
important because here we access multiple nodes from one process_node() method
and we need to be sure that all the other nodes already have their enhanced
attribute.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018, 2019 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

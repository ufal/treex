package Treex::Tool::PhraseBuilder::PragueToUD;
use namespace::autoclean;
use Moose;
use Treex::Core::Common;

extends 'Treex::Tool::PhraseBuilder::ToUD';

has 'cop_is_head' =>
(
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 0,
    documentation =>
        'Should copula head its phrase? '.
        'See Treex::Core::Phrase::PP, fun_is_head attribute.'
);

has 'counted_genitives' =>
(
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 1,
    documentation =>
        'Shall we detect counted nouns in genitive and transform them? '.
        'This should not be called e.g. in the Index Thomisticus Treebank.'
);



#------------------------------------------------------------------------------
# Examines a nonterminal phrase and tries to recognize certain special phrase
# types. This is the part of phrase building that is specific to expected input
# style and desired output style. This method is called from the core phrase
# building implemented in Treex::Core::Phrase::Builder, after a new nonterminal
# phrase is built.
#------------------------------------------------------------------------------
sub detect_special_constructions
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # The root node must not participate in any specialized construction.
    unless($phrase->node()->is_root())
    {
        # Despite the fact that we work bottom-up, the order of these detection
        # methods matters. There may be multiple special constructions on the same
        # level of the tree. For example: We see a phrase labeled Coord (coordination),
        # hence we do not see a prepositional phrase (the label would have to be AuxP
        # instead of Coord). However, after processing the coordination the phrase
        # will get a new label and it may well be AuxP.
        $phrase = $self->detect_multi_word_expression($phrase);
        $phrase = $self->detect_prague_coordination($phrase);
        $phrase = $self->detect_prague_pp($phrase);
        $phrase = $self->detect_colon_predicate($phrase);
        $phrase = $self->detect_prague_copula($phrase);
        $phrase = $self->detect_name_phrase($phrase);
        $phrase = $self->detect_compound_numeral($phrase);
        $phrase = $self->detect_counted_noun_in_genitive($phrase) if($self->counted_genitives());
        $phrase = $self->detect_indirect_object($phrase);
        $phrase = $self->detect_controlled_verb($phrase);
        $phrase = $self->detect_controlled_subject($phrase);
    }
    else
    {
        $phrase = $self->detect_root_phrase($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



#------------------------------------------------------------------------------
# Looks for compound numeral phrases, i.e. two or more cardinal numerals
# connected by the nummod relation. Changes the relation to compound. This
# method does not care whether the relation goes left-to-right or right-to-left
# and whether there are nested compounds (or a multi-level compound).
#------------------------------------------------------------------------------
sub detect_compound_numeral
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Is the head a cardinal numeral and are there non-core children that are
    # cardinal numerals?
    my @dependents = $phrase->dependents();
    my @cnum = grep {$_->node()->is_cardinal() && $_->node()->iset()->prontype() eq ''} (@dependents);
    if($phrase->node()->is_cardinal() && $phrase->node()->iset()->prontype() eq '' && scalar(@cnum)>=1)
    {
        my @rest = grep {!$_->node()->is_cardinal() || $_->node()->iset()->prontype() ne ''} (@dependents);
        # The current phrase is a number, too.
        # Detach the dependents first, so that we can put the current phrase on the same level with the other names.
        foreach my $d (@dependents)
        {
            $d->set_parent(undef);
        }
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Create a new nonterminal phrase for the compound numeral only.
        my $cnumphrase = new Treex::Core::Phrase::NTerm('head' => $phrase);
        foreach my $n (@cnum)
        {
            $n->set_parent($cnumphrase);
            $self->set_deprel($n, 'compound');
            $n->set_is_member(0);
        }
        # Create a new nonterminal phrase that will group the numeral phrase with
        # the original non-numeral dependents, if any.
        if(scalar(@rest)>=1)
        {
            $phrase = new Treex::Core::Phrase::NTerm('head' => $cnumphrase);
            foreach my $d (@rest)
            {
                $d->set_parent($phrase);
                $d->set_is_member(0);
            }
        }
        else
        {
            $phrase = $cnumphrase;
        }
        $phrase->set_deprel($deprel);
        $phrase->set_is_member($member);
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Makes sure that numerals modify counted nouns, not vice versa. (In PDT, both
# directions are possible under certain circumstances.)
# Note that this transformation is not suitable for all Prague-style treebanks.
# In the Index Thomisticus Treebank, there are genitives attached to numerals
# but it is always a construction of the type "one of them", "unum eorum", and
# it should not be transformed. Thus a parameter of this class can turn it on.
#------------------------------------------------------------------------------
sub detect_counted_noun_in_genitive
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Is the head a cardinal numeral and are there non-core children that are
    # nominals (nouns or pronouns) in genitive? Do not count genitives with
    # adpositions (e.g. [cs] "5 ze 100 obyvatel", "5 per 100 inhabitants").
    if($phrase->node()->is_cardinal())
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        my @gen;
        my @rest;
        # Find counted noun in genitive.
        foreach my $d (@dependents)
        {
            my $ok = $d->node()->is_noun() && $d->node()->iset()->case() eq 'gen';
            if($ok)
            {
                my @dchildren = $d->children();
                $ok = $ok && !any {$_->node()->is_adposition()} (@dchildren);
                $ok = $ok && !$self->is_deprel($d->deprel(), 'appos');
            }
            if($ok)
            {
                push(@gen, $d);
            }
            else
            {
                push(@rest, $d);
            }
        }
        if(scalar(@gen)>=1)
        {
            # We do not expect more than one genitive noun phrase. If we encounter them,
            # we will just take the first one and treat the others as normal dependents.
            my $counted_noun = shift(@gen);
            push(@rest, @gen) if(@gen);
            # We may not be able to just set the counted noun as the new head. If it is a Coordination, there are other rules for finding the head.
            ###!!! Maybe we should extend the set_head() method to special nonterminals? It would create an extra NTerm phrase, move the dependents
            ###!!! there and set the core as its head? That's what we will do here anyway, and it has been needed repeatedly.
            # Detach the counted noun but not the other dependents. If there is anything else attached directly to the numeral,
            # it should probably stay there. Example [cs]: "ze 128 křesel jich 94 připadne..." "jich" is the counted nominal, "94" is the number
            # and "ze 128 křesel" ("out of 128 seats") modifies the number, not the nominal.
            # Unfortunately there are also counterexamples and from the original Prague annotation we cannot decide what modifies the numeral and what the counted noun.
            # If the noun is "procent" or "kilometrů", then it is quite likely that the modifier should be attached to the nominal ("31.5 kilometru od pobřeží").
            $counted_noun->set_parent(undef);
            my $deprel = $phrase->deprel();
            my $member = $phrase->is_member();
            $phrase->set_is_member(0);
            # If the deprel convertor returned nummod or its relatives, it means that the whole phrase (numeral+nominal)
            # originally modified another nominal as Atr. Since the counted noun is now going to head the phrase, we
            # have to change the deprel to nmod. We would not change the deprel if it was nsubj, dobj, appos etc.
            if($self->is_deprel($deprel, 'nummod'))
            {
                ###!!! We must translate the label to the current dialect!
                $deprel = 'nmod';
            }
            # Create a new nonterminal phrase with the counted noun as the head.
            my $ntphrase = new Treex::Core::Phrase::NTerm('head' => $counted_noun);
            # Attach the numeral also as a dependent to the new phrase.
            $phrase->set_parent($ntphrase);
            ###!!! We must translate the labels to the current dialect!
            $phrase->set_deprel($phrase->node()->iset()->prontype() eq '' ? 'nummod:gov' : 'det:numgov');
            $phrase->set_is_member(0);
            $phrase = $ntphrase;
            $phrase->set_deprel($deprel);
            $phrase->set_is_member($member);
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# The Prague treebanks do not distinguish direct and indirect objects. There is
# only one object relation, Obj. In Universal Dependencies we have to select
# one object of each verb as the main one (dobj), the others should be labeled
# as indirect (iobj). There is no easy way of doing this, but we can use a few
# heuristics to solve at least some cases.
#------------------------------------------------------------------------------
sub detect_indirect_object
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Only look for objects under verbs.
    if($phrase->node()->is_verb())
    {
        my @dependents = $phrase->dependents();
        # If there is a clausal complement (ccomp or xcomp), we assume that it
        # takes the role of the direct object. Any other object will be labeled
        # as indirect.
        if(any {$self->is_deprel($_->deprel(), 'cxcomp')} (@dependents))
        {
            foreach my $d (@dependents)
            {
                if($self->is_deprel($d->deprel(), 'dobj'))
                {
                    $self->set_deprel($d, 'iobj');
                }
            }
        }
        # If there is an accusative object without preposition, all other objects are indirect.
        elsif(any {$self->is_deprel($_->deprel(), 'dobj') && $self->get_phrase_case($_) eq 'acc'} (@dependents))
        {
            foreach my $d (@dependents)
            {
                if($self->is_deprel($d->deprel(), 'dobj') && $self->get_phrase_case($d) ne 'acc')
                {
                    $self->set_deprel($d, 'iobj');
                }
            }
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Clausal complements should be labeled ccomp or xcomp, whereas xcomp is
# reserved for controlled verbs whose subject is inherited from the controlling
# verb. This means (at least in some languages) that the controlled verb is in
# infinitive. However, we have to check that the infinitive form is not caused
# by the periphrastic future tense (cs: "bude následovat"). In such cases the
# whole verb group (auxiliary + main verb) is actually finite and uncontrolled.
# They have their own subject independent of the governing verb (cs: "Ti
# odhadují, že po uvolnění cen nebude následovat jejich okamžitý vzestup.")
#------------------------------------------------------------------------------
sub detect_controlled_verb
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Only look for clausal complements headed by verbs.
    # We assume that ccomp has been initially changed to xcomp wherever infinitive was seen,
    # so now we only check that the infinitive is genuine.
    if($phrase->node()->is_infinitive() && $self->is_deprel($phrase->deprel(), 'xcomp'))
    {
        my @dependents = $phrase->dependents();
        if(any {$self->is_deprel($_->deprel(), 'auxv') && $_->node()->iset()->tense() eq 'fut'} (@dependents))
        {
            $self->set_deprel($phrase, 'ccomp');
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Infinitives controlled by other verbs (xcomp) cannot have their own subject.
# The subject must be attached directly to the controlling verb. This rule
# holds even in the Prague treebanks but it is occasionally violated due to
# annotation errors. This method tries to detect such instances and fix them.
# It must not be called before xcomp labels are fixed (see detect_controlled_
# verb() above)!
#------------------------------------------------------------------------------
sub detect_controlled_subject
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Look for controlling verb that does not have its own overt subject.
    if($phrase->node()->is_verb())
    {
        my @dependents = $phrase->dependents();
        my @controlled_infinitives = grep {$self->is_deprel($_->deprel(), 'xcomp') && $_->node()->is_infinitive()} (@dependents);
        my $has_subject = any {$self->is_deprel($_->deprel(), 'subj')} (@dependents);
        if(scalar(@controlled_infinitives)>0 && !$has_subject)
        {
            # It is not clear what we should do if there is more than one infinitive and they are not in coordination.
            # We assume that there should be just one and we will take the first one if there are more.
            # If there is a coordination of infinitives, we can only fix the error if they share one subject.
            # If the subject(s) is (are) attached as private dependents of the conjuncts, we will not fix them.
            my $infinitive = shift(@controlled_infinitives);
            my @subjects = grep {$self->is_deprel($_->deprel(), 'subj')} ($infinitive->dependents());
            if(scalar(@subjects)>0)
            {
                # Again, more than one subject (uncoordinate) does not make sense. Let's take the first one.
                my $subject = shift(@subjects);
                $subject->set_parent($phrase);
            }
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Figures out the generalized case of a phrase, consisting of word forms of any
# children with the 'case' relation, and the value of the morphological case of
# the head word.
#------------------------------------------------------------------------------
sub get_phrase_case
{
    my $self = shift;
    my $phrase = shift;
    my $case = '';
    my $node = $phrase->node();
    # Prepositions may also have the case feature but in their case it is valency, i.e. the required case of their nominal argument.
    unless($node->is_adposition())
    {
        # Does the phrase have any children (probably core children) attached as case?
        my @children = $phrase->children();
        my @case_forms = map {$_->node()->form()} (grep {$self->is_deprel($_->deprel(), 'auxp')} (@children));
        # Does the head node have the case feature?
        my $head_case = $node->iset()->case();
        push(@case_forms, $head_case) unless($head_case eq '');
        if(@case_forms)
        {
            $case = join('+', @case_forms);
        }
    }
    return $case;
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
sub detect_colon_predicate
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    my $deprel = $phrase->deprel();
    my $node = $phrase->node();
    ###!!! Should we test that we are dealing with Phrase::NTerm and not e.g. with Phrase::Coordination?
    if(defined($node->parent()) && $node->parent()->is_root() && $node->form() eq ':')
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        # Make the first child of the colon the new top node.
        # We want a non-punctuation child. If there are only punctuation children, do not do anything.
        my @npunct = grep {!$_->node()->is_punctuation()} (@dependents);
        my @punct  = grep { $_->node()->is_punctuation()} (@dependents);
        if(scalar(@npunct)>=1)
        {
            my $old_head = $phrase->head();
            my $new_head = shift(@npunct);
            $phrase->set_head($new_head);
            $phrase->set_deprel($deprel);
            $self->set_deprel($old_head, 'punct');
            # All other children of the colon (if any; probably just one other child) will be attached to the new head as apposition.
            foreach my $d (@npunct)
            {
                $self->set_deprel($d, 'appos');
            }
        }
    }
    # Return the modified phrase as with all detect methods.
    return $phrase;
}



#------------------------------------------------------------------------------
# Checks whether the head node of a phrase is the artificial root of the
# dependency tree. If so, then it makes sure that there is only one dependent
# and its deprel is "root" (there is a consensus in Universal Dependencies that
# there should be always just one node attached to the artificial root and
# labeled "root"). If there were multiple dependents, the leftmost will be kept
# and the others will be made its dependents (and grandchildren of the
# artificial root node).
#------------------------------------------------------------------------------
sub detect_root_phrase
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    if($phrase->node()->is_root())
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        # The artificial root node cannot have more than one child.
        if(scalar(@dependents)>1)
        {
            # Avoid punctuation as the head if possible.
            my @punct = grep {$_->node()->is_punctuation()} (@dependents);
            my @npunct = grep {!$_->node()->is_punctuation()} (@dependents);
            my $leftmost;
            if(@npunct)
            {
                $leftmost = shift(@npunct);
                @dependents = (@npunct, @punct);
            }
            else
            {
                $leftmost = shift(@dependents);
            }
            $leftmost->set_parent(undef);
            # Create a new nonterminal phrase with the leftmost dependent as head and the others as dependents.
            my $subphrase = new Treex::Core::Phrase::NTerm('head' => $leftmost);
            foreach my $d (@dependents)
            {
                $d->set_parent($subphrase);
                # Solve the sentence-final punctuation at the same time.
                if($self->is_deprel($d->deprel(), 'auxk'))
                {
                    $self->set_deprel($d, 'punct');
                }
                # If a Pnom was attached directly to the root (e.g. in Arabic), it did not go through the copula inversion
                # and its deprel is still dep:pnom. Change it to something compatible with Universal Dependencies.
                if($self->is_deprel($d->deprel(), 'pnom'))
                {
                    $self->set_deprel($d, 'parataxis');
                }
            }
            $subphrase->set_parent($phrase);
            @dependents = ($subphrase);
        }
        # The child of the artificial root node is always attached with the label "root".
        if(scalar(@dependents)>0)
        {
            $self->set_deprel($dependents[0], 'root');
        }
    }
    # Return the modified phrase as with all detect methods.
    return $phrase;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::PragueToUD

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

There are methods that detect structures in a Prague-style treebank (such as
the Czech Prague Dependency Treebank), with dependency relation labels
(analytical functions) converted to Universal Dependencies (see
C<Treex::Block::HamleDT::Udep> for details). All restructuring and relabeling
done here is directed towards the Universal Dependencies annotation style.

Transformations organized bottom-up during phrase building are advantageous
because we can rely on that all special structures (such as coordination) on the
lower levels have been detected and treated properly so that we will not
accidentially destroy them.

In the future we will define other phrase builders for other annotation styles.

=head1 METHODS

=over

=item build

Wraps a node (and its subtree, if any) in a phrase.

=item detect_prague_pp

Examines a nonterminal phrase in the Prague style. If it recognizes
a prepositional phrase, transforms the general nonterminal to PP.
Returns the resulting phrase (if nothing has been changed, returns
the original phrase).

=item detect_prague_coordination

Examines a nonterminal phrase in the Prague style (with analytical functions
converted to dependency relation labels based on Universal Dependencies). If
it recognizes a coordination, transforms the general NTerm to Coordination.

=item detect_name_phrase

Looks for name phrases, i.e. two or more proper nouns connected by the name
relation. Makes sure that the leftmost name is the head (usually the opposite
to PDT where family names are heads and given names are dependents). The
method currently does not search for nested name phrases (which, if they
they exist, we might want to merge with the current level).

=item detect_colon_predicate

The colon is sometimes treated as a substitute for the main predicate in PDT
(usually the hypothetical predicate would equal to I<is>).

Example:
I<Veletrh GOLF 94 München: 2. – 4. 9.>
(“GOLF 94 fair Munich: September 2 – 9”)

We will make the first part the main constituent, and attach the second part
as apposition. In some cases the colon is analyzed as copula (and the second
part is a nominal predicate) so we want to do this before copulas are
processed. Otherwise the scene will be reshaped and we will not recognize it.

=item detect_controlled_verb

Clausal complements should be labeled C<ccomp> or C<xcomp>, whereas C<xcomp> is
reserved for controlled verbs whose subject is inherited from the controlling
verb. This means (at least in some languages) that the controlled verb is in
infinitive. However, we have to check that the infinitive form is not caused
by the periphrastic future tense (cs: I<bude následovat>). In such cases the
whole verb group (auxiliary + main verb) is actually finite and uncontrolled.
They have their own subject independent of the governing verb (cs: I<Ti
odhadují, že po uvolnění cen nebude následovat jejich okamžitý vzestup.>)

=item detect_controlled_subject

Infinitives controlled by other verbs (C<xcomp>) cannot have their own subject.
The subject must be attached directly to the controlling verb. This rule
holds even in the Prague treebanks but it is occasionally violated due to
annotation errors. This method tries to detect such instances and fix them.
It must not be called before xcomp labels are fixed (see detect_controlled_
verb() above)!

=item detect_root_phrase

Checks whether the head node of a phrase is the artificial root of the
dependency tree. If so, then it makes sure that there is only one dependent
and its deprel is "root" (there is a consensus in Universal Dependencies that
there should be always just one node attached to the artificial root and
labeled "root"). If there were multiple dependents, the leftmost will be kept
and the others will be made its dependents (and grandchildren of the
artificial root node).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

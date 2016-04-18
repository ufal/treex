package Treex::Tool::PhraseBuilder::ToUD;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;

extends 'Treex::Tool::PhraseBuilder::BasePhraseBuilder';



#------------------------------------------------------------------------------
# Defines the dialect of the labels used in Universal Dependencies (Stanford).
# What dependency labels are used? By separating the labels from the other code
# we can share some transformation methods that are useful for multiple target
# styles.
#------------------------------------------------------------------------------
sub _build_dialect
{
    # A lazy builder can be called from anywhere, including map or grep. Protect $_!
    local $_;
    # Mapping from id to regular expression describing corresponding deprels in the dialect.
    # The second position is the label used in set_deprel(); not available for all ids.
    my %map =
    (
        'apos'      => ['^apos$', 'apos'],   # head of paratactic apposition (punctuation or conjunction)
        'appos'     => ['^appos$', 'appos'], # dependent member of hypotactic apposition
        'auxpc'     => ['^case|mark$'],      # adposition or subordinating conjunction
        'auxp'      => ['^case$', 'case'],   # adposition
        'auxc'      => ['^mark$', 'mark'],   # subordinating conjunction
        'psarg'     => ['^(adp|sc)arg$'],    # argument of adposition or subordinating conjunction
        'parg'      => ['^adparg$', 'adparg'], # argument of adposition
        'sarg'      => ['^scarg$', 'scarg'], # argument of subordinating conjunction
        'punct'     => ['^punct$', 'punct'], # punctuation
        'auxx'      => ['^punct$', 'punct'], # comma
        'auxg'      => ['^punct$', 'punct'], # punctuation other than comma
        'auxk'      => ['^punct$', 'punct'], # sentence-terminating punctuation
        'auxy'      => ['^cc$', 'cc'],       # additional coordinating conjunction or other function word
        'auxyz'     => ['^(advmod:emph|cc)$'],
        'cc'        => ['^cc$', 'cc'],       # coordinating conjunction
        'conj'      => ['^conj$', 'conj'],   # conjunct
        'coord'     => ['^coord$', 'coord'], # head of coordination (conjunction or punctuation)
        'mwe'       => ['^mwe$', 'mwe'],     # non-head word of a multi-word expression; PDT has only multi-word prepositions
        'compound'  => ['^compound$', 'compound'], # non-head word of a compound
        'det'       => ['^det$', 'det'],       # determiner attached to noun
        'detarg'    => ['^detarg$', 'detarg'], # noun attached to determiner
        'nummod'    => ['^nummod$', 'nummod'], # numeral attached to counted noun
        'numarg'    => ['^numarg$', 'numarg'], # counted noun attached to numeral
        'amod'      => ['^amod$', 'amod'],     # adjective attached to noun
        'adjarg'    => ['^adjarg$', 'adjarg'], # noun attached to adjective that modifies it
        'genmod'    => ['^nmod$', 'nmod'],     # genitive or possessive noun attached to the modified (possessed) noun
        'genarg'    => ['^genarg$', 'genarg'], # possessed (modified) noun attached to possessive (genitive) noun that modifies it
        'pnom'      => ['^pnom$', 'pnom'],     # nominal predicate (predicative adjective or noun) attached to a copula
        'cop'       => ['^cop$', 'cop'],       # copula attached to a nominal predicate
        'subj'      => ['subj'],               # subject (nominal or clausal, active or passive)
        'nsubj'     => ['^nsubj$', 'nsubj'],   # nominal subject in active clause
        'nmod'      => ['^nmod$', 'nmod'],     # nominal modifier (attribute or adjunct)
        'advmod'    => ['^advmod$', 'advmod'], # adverbial modifier (realized as adverb, not as a noun phrase)
        'name'      => ['^name$', 'name'],     # non-head part of a multi-word named entity without internal syntactic structure
        'auxarg'    => ['^auxarg$', 'auxarg'], # content verb (participle) attached to an auxiliary verb (finite)
        'auxv'      => ['^aux$', 'aux'],       # auxiliary verb attached to a main (content) verb
        'xcomp'     => ['^xcomp$', 'xcomp'],   # controlled verb (usually non-finite) attached to a controlling verb
        'ccomp'     => ['^ccomp$', 'ccomp'],   # complement clause that is not xcomp (note that non-core subordinate clauses are acl or advcl)
        'cxcomp'    => ['^[cx]comp$'],
        'dobj'      => ['^dobj$', 'dobj'],     # direct nominal object
        'iobj'      => ['^iobj$', 'iobj'],     # indirect nominal object
        'parataxis' => ['^parataxis$', 'parataxis'], # loosely attached clause
        'root'      => ['^root$', 'root'],     # the top node attached to the artificial root
    );
    return \%map;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style (with analytical functions
# converted to dependency relation labels based on Universal Dependencies).
# If it recognizes a copula construction, transforms the general NTerm to PP.
#------------------------------------------------------------------------------
sub detect_prague_copula
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the copula (if any) must be the head.
    my @pnom = grep {$self->is_deprel($_->deprel(), 'pnom')} ($phrase->dependents('ordered' => 1));
    if(scalar(@pnom)>=1)
    {
        # Now it is clear that we have a nominal predicate with copula.
        # If this is currently an ordinary NTerm phrase, its head is the copula.
        # However, it is also possible that we have a special phrase such as coordination.
        # Then we cannot just take the head. The whole core of the phrase is the copula.
        # (For coordinate copulas, consider "he is and always was the best goalkeeper".)
        # Therefore we will remove the dependents and keep the core phrase as the copula.
        # For ordinary NTerm phrases this will add one unnecessary (but harmless) layer around the head.
        my $copula = $phrase;
        # Note that the nominal predicate can also be seen as the argument of the copula,
        # and we will denote it as $argument here, which is the terminology inside Phrase::PP.
        my $argument;
        # There should not be more than one nominal predicate but it is not guaranteed.
        # There are about 40 sentences even in PDT; all of them are annotation errors.
        # We will try to identify the most probable predicate; but note that these
        # heuristics may be language-dependent.
        if(scalar(@pnom)==1)
        {
            $argument = shift(@pnom);
        }
        else
        {
            # Look for an adjective in nominative (or without case marking).
            my @selection = grep {$_->node()->is_adjective() && $_->node()->iset()->case() =~ m/^(nom)?$/} (@pnom);
            if(@selection)
            {
                $argument = shift(@selection);
            }
            else
            {
                # Look for a participle.
                @selection = grep {$_->node()->is_participle()} (@pnom);
                if(@selection)
                {
                    $argument = shift(@selection);
                }
                else
                {
                    # Look for a noun.
                    # (Specific for Czech: the noun will usually be in nominative or instrumental.
                    # But it can also be in genitive (transformed phrases with counted nouns).)
                    # We will not check the case here as the benefit is negligible.
                    # However, we will take the last noun, not the first one. A frequent annotation
                    # error is that the subject is labeled as Pnom, and the configuration where
                    # subject precedes predicate is more likely.
                    @selection = grep {$_->node()->is_noun()} (@pnom);
                    if(@selection)
                    {
                        $argument = pop(@selection);
                    }
                    else
                    {
                        # No typical nominal predicates found. Take the last candidate.
                        $argument = pop(@pnom);
                    }
                }
            }
            # The unselected candidates must receive a dependency relation label (at the moment they only have 'pnom').
            my $subject_exists = any {$self->is_deprel($_->deprel(), 'subj')} ($phrase->dependents());
            foreach my $x (@pnom)
            {
                unless($x == $argument)
                {
                    if($x->node()->is_noun() || $x->node()->is_adjective() || $x->node()->is_numeral() || $x->node()->is_participle())
                    {
                        if($subject_exists)
                        {
                            $self->set_deprel($x, 'nmod');
                        }
                        else
                        {
                            $self->set_deprel($x, 'nsubj');
                        }
                    }
                    else
                    {
                        $self->set_deprel($x, 'advmod');
                    }
                }
            }
        }
        my @dependents = grep {$_ != $argument} ($phrase->dependents());
        my $parent = $phrase->parent();
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $copula->set_parent(undef);
        $argument->set_parent(undef);
        # Copula is sometimes represented by a punctuation sign (dash, colon) instead of the verb "to be".
        # Punctuation should not be attached as cop.
        my $fun_deprel = $copula->node()->is_punctuation() ? 'punct' : 'cop';
        $self->set_deprel($copula, $fun_deprel);
        my $pp = new Treex::Core::Phrase::PP
        (
            'fun'           => $copula,
            'arg'           => $argument,
            'fun_is_head'   => 0,
            'deprel_at_fun' => 0,
            'core_deprel'   => 'cop',
            'is_member'     => $member
        );
        $pp->set_deprel($deprel);
        $pp->set_parent($parent);
        foreach my $d (@dependents)
        {
            $d->set_parent($pp);
        }
        return $pp;
    }
    # Return the input phrase if no PP has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Looks for multi-word expressions, i.e. two or more nodes connected by the mwe
# relation. Makes sure that the leftmost node is the head. MWEs in UD are
# supposed to be flat and this method does not search recursively for nested
# mwe relations. Prague treebanks do not have an equivalent of the mwe relation
# but it may be recognized and introduced during conversion.
#------------------------------------------------------------------------------
sub detect_multi_word_expression
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Are there any non-core children attached as mwe?
    my @dependents = $phrase->dependents();
    my @mwe = grep {$self->is_deprel($_->deprel(), 'mwe')} (@dependents);
    if(scalar(@mwe)>=1)
    {
        my @nonmwe = grep {!$self->is_deprel($_->deprel(), 'mwe')} (@dependents);
        # If there are mwe children, then the current phrase is a mwe, too.
        # Detach the dependents first, so that we can put the current phrase on the same level with the other mwes.
        foreach my $d (@dependents)
        {
            $d->set_parent(undef);
        }
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Add the current phrase (without dependents) to the mwes and order them.
        push(@mwe, $phrase);
        @mwe = sort {$a->ord() <=> $b->ord()} (@mwe);
        # Create a new nonterminal phrase for the mwe only.
        # (In the future we may also want to create a new subclass of nonterminal
        # phrases specifically for head-first multi-word segments. But it is not
        # necessary for transformations to work, so let's keep this for now.)
        my $mwephrase = new Treex::Core::Phrase::NTerm('head' => shift(@mwe));
        foreach my $n (@mwe)
        {
            $n->set_parent($mwephrase);
            $self->set_deprel($n, 'mwe');
            $n->set_is_member(0);
        }
        # Create a new nonterminal phrase that will group the mwe phrase with
        # the original non-mwe dependents, if any.
        if(scalar(@nonmwe)>=1)
        {
            $phrase = new Treex::Core::Phrase::NTerm('head' => $mwephrase);
            foreach my $d (@nonmwe)
            {
                $d->set_parent($phrase);
                $d->set_is_member(0);
            }
        }
        else
        {
            $phrase = $mwephrase;
        }
        $phrase->set_deprel($deprel);
        $phrase->set_is_member($member);
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Looks for name phrases, i.e. two or more proper nouns connected by the name
# relation. Makes sure that the leftmost name is the head (usually the opposite
# to PDT where family names are heads and given names are dependents). The
# method currently does not search for nested name phrases (which, if they
# they exist, we might want to merge with the current level).
#------------------------------------------------------------------------------
sub detect_name_phrase
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Are there any non-core children attached as name?
    my @dependents = $phrase->dependents();
    my @name = grep {$self->is_deprel($_->deprel(), 'name')} (@dependents);
    if(scalar(@name)>=1)
    {
        my @nonname = grep {!$self->is_deprel($_->deprel(), 'name')} (@dependents);
        # If there are name children, then the current phrase is a name, too.
        # Detach the dependents first, so that we can put the current phrase on the same level with the other names.
        foreach my $d (@dependents)
        {
            $d->set_parent(undef);
        }
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Add the current phrase (without dependents) to the names and order them.
        push(@name, $phrase);
        @name = sort {$a->ord() <=> $b->ord()} (@name);
        # Create a new nonterminal phrase for the name only.
        # (In the future we may also want to create a new subclass of nonterminal
        # phrases specifically for head-first multi-word segments. But it is not
        # necessary for transformations to work, so let's keep this for now.)
        my $namephrase = new Treex::Core::Phrase::NTerm('head' => shift(@name));
        foreach my $n (@name)
        {
            $n->set_parent($namephrase);
            $self->set_deprel($n, 'name');
            $n->set_is_member(0);
        }
        # Create a new nonterminal phrase that will group the name phrase with
        # the original non-name dependents, if any.
        if(scalar(@nonname)>=1)
        {
            $phrase = new Treex::Core::Phrase::NTerm('head' => $namephrase);
            foreach my $d (@nonname)
            {
                $d->set_parent($phrase);
                $d->set_is_member(0);
            }
        }
        else
        {
            $phrase = $namephrase;
        }
        $phrase->set_deprel($deprel);
        $phrase->set_is_member($member);
    }
    return $phrase;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::ToUD

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

This class defines the UD dialect of dependency relation labels, including
some labels that are actually not used in UD but may be needed during the
conversion to denote relations that will later be transformed.

It is assumed that any conversion process begins with translating the deprels
to something close to the target label set. Then the subtrees are identified
whose internal structure does not adhere to the target annotation style. These
are transformed (restructured). Labels that are not valid in the target label
set will disappear during the transformation.

This class may also define transformations specific to the target annotation
style. They may or may not depend on a particular source style. Classes
derived from this class will be designed for concrete source-target pairs
and will select which transformations shall be actually performed.

=head1 METHODS

=over

=item build

Wraps a node (and its subtree, if any) in a phrase.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

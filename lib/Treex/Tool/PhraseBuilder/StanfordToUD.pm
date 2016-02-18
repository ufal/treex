package Treex::Tool::PhraseBuilder::StanfordToUD;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;

extends 'Treex::Tool::PhraseBuilder::ToUD';



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
        ###!!! The following comment should be modified and maybe the order
        ###!!! of the following calls too. Stanford-to-UD conversion does not
        ###!!! work with the PrepArg label.
        # Despite the fact that we work bottom-up, the order of these detection
        # methods matters. There may be multiple special constructions on the same
        # level of the tree. For example: coordination of prepositional phrases.
        # The first conjunct is the head of the coordination and it is also a preposition.
        # If we restructure the coordination before attending to the prepositional
        # phrase, we will move the preposition to a lower level and it will be
        # never discovered that it has a PrepArg child.
        $phrase = $self->detect_stanford_pp($phrase);
        $phrase = $self->detect_prague_copula($phrase); ###!!! Perhaps we should rename this method to detect_copula_head().
        $phrase = $self->detect_stanford_coordination($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
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
            # The unselected candidates must receive a dependency relation label (at the moment they only have 'dep:pnom').
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



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::StanfordToUD

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

It expects that the dependency relation labels have been translated to the
Universal Dependencies dialect. The expected tree structure features Stanford
coordination and prepositional phrases headed by the preposition.
The target style is Universal Dependencies.

Input treebanks for which this builder should work include the Google Universal
Dependency Treebanks version 2.0 (spring 2014).

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

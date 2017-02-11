package Treex::Block::HamleDT::HR::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_relations($root);
}



#------------------------------------------------------------------------------
# Fixes known issues in lemma, tag and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        # Dative vs. locative.
        # Croatian nominals have almost always identical forms of dative and locative, both in singular and plural.
        # The treebank distinguishes the two features (case=dat and case=loc) but there are annotation errors.
        # Assume that it cannot be locative if there is no preposition.
        # (Warning: There is also a valency case at prepositions. That should not be modified.)
        # (Warning 2: Determiners and adjectives may be siblings of the preposition rather than its parents!)
        # (Warning 3: If the node or its parent is attached as conj, the rules are even more complex. Give up. Same for appos and flat parent.)
        # (Warning 4: It seems to introduce more problems than it solves, also because the dependencies are not always reliable. Give up for now.)
        if(0 && $node->is_locative() && !$node->is_adposition() && $node->deprel() ne 'conj' && $node->parent()->deprel() !~ m/^(conj|appos)$/)
        {
            my @prepositions = grep {$_->is_adposition()} ($node->children());
            if(scalar(@prepositions)==0 && $node->parent()->iset()->case() =~ m/dat|loc/)
            {
                @prepositions = grep {$_->is_adposition()} ($node->parent()->children());
            }
            if(scalar(@prepositions)==0)
            {
                $iset->set('case', 'dat');
            }
        }
        # Pronominal words.
        if($node->is_pronominal())
        {
            # Reflexive pronouns lack PronType=Prs.
            # On the other hand they have Number=Sing while they are used in plural as well.
            if($lemma eq 'sebe')
            {
                $iset->add('prontype' => 'prs', 'number' => '');
            }
            # Possessive determiners.
            elsif($lemma =~ m/^(moj|tvoj)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'sing');
            }
            elsif($lemma =~ m/^(njegov)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'sing', 'possgender' => 'masc|neut');
            }
            elsif($lemma =~ m/^(njezin|njen)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'sing', 'possgender' => 'fem');
            }
            elsif($lemma =~ m/^(naš|vaš|njihov)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'plur');
            }
            # Reflexive possessive determiners.
            elsif($lemma eq 'svoj')
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss');
            }
            # Interrogative or relative pronouns "tko" and "što" are now tagged as indefinite.
            elsif($lemma eq 'tko')
            {
                # It is not customary to show the person of relative pronouns, but in UD_Croatian they currently have Person=3.
                $iset->add('prontype' => 'int|rel', 'person' => '');
            }
            # If "što" works like a subordinating conjunction, it should be tagged as such.
            # We cannot recognize such cases reliably (the deprel "mark" is currently used also with real pronouns).
            # But if it is in nominative and the clause already has a subject, it is suspicious.
            elsif($lemma eq 'što')
            {
                if($node->deprel() eq 'mark' && $iset->is_nominative() && any {$_->deprel() =~ m/subj/} ($node->parent()->children()))
                {
                    $iset->set_hash({'pos' => 'conj', 'conjtype' => 'sub'});
                }
                else
                {
                    # It is not customary to show the person of relative pronouns, but in UD_Croatian they currently have Person=3.
                    $iset->add('prontype' => 'int|rel', 'person' => '');
                }
            }
            # Relative determiner "koji" is now tagged PRON Ind.
            # Do not damage cases that were already disambiguated as interrogative (and not relative).
            elsif($lemma =~ m/^(kakav|koji|koliki)$/)
            {
                $iset->add('pos' => 'adj');
                unless($iset->prontype() eq 'int')
                {
                    $iset->add('prontype' => 'int|rel');
                }
            }
            # Interrogative or relative possessive determiner "čiji" ("whose").
            elsif($lemma eq 'čiji')
            {
                $iset->add('pos' => 'adj', 'prontype' => 'int|rel', 'poss' => 'poss');
            }
        }
        # Verbal copulas should be AUX and not VERB.
        if($node->is_verb() && $node->deprel() eq 'cop')
        {
            # The only copula verb is "biti".
            if($lemma !~ m/^(biti|bivati)$/)
            {
                log_warn("Copula verb should have lemma 'biti/bivati' but this one has '$lemma'");
            }
            $iset->set('verbtype', 'aux');
        }
        # Passive participles should have the voice feature.
        # And some of them lack even the verbform feature!
        if($node->is_participle() || $lemma =~ m/^(predviđen|zaključen)$/)
        {
            $iset->set('verbform', 'part');
            # Is there an aux:pass, expl:pass, nsubj:pass or csubj:pass child?
            my @passchildren = grep {$_->deprel() =~ m/:pass$/} ($node->children());
            if(scalar(@passchildren) >= 1)
            {
                $iset->set('voice' => 'pass');
            }
        }
        # "jedem" (I eat), lemma "jesti", is tagged NOUN and not VERB? Annotation error.
        if($node->form() eq 'jedem' && $lemma eq 'jesti' && $node->is_noun())
        {
            $iset->set_hash({'pos' => 'verb', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'number' => 'sing', 'person' => '1'});
        }
    }
}



#------------------------------------------------------------------------------
# After changes done to Interset (including part of speech) generates the
# universal part-of-speech tag anew.
#------------------------------------------------------------------------------
sub regenerate_upos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        $node->set_tag($node->iset()->get_upos());
    }
}



#------------------------------------------------------------------------------
# Fixes known issues in dependency relations.
#------------------------------------------------------------------------------
sub fix_relations
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # Reflexive pronouns of inherently reflexive verbs should be attached as expl:pv, not as compound (UD guideline).
        if($node->is_reflexive() && $node->deprel() eq 'compound')
        {
            $node->set_deprel('expl:pv');
        }
        # Relative pronouns and determiners must not be attached as mark because they are not subordinating conjunctions (although they do subordinate).
        # They must show the core function they have wrt the predicate of the subordinate clause.
        # WARNING: "što" can be also used as a subordinating conjunction: "Dobro je što nam pružaju više informacija."
        # But then it should be tagged SCONJ, not PRON!
        if($node->lemma() =~ m/^(tko|što|kakav|koji)$/ && $node->deprel() eq 'mark')
        {
            if($node->is_nominative())
            {
                $node->set_deprel('nsubj');
            }
            elsif($node->parent()->is_verb() || $node->parent()->is_participle())
            {
                if($node->is_accusative())
                {
                    $node->set_deprel('obj');
                }
                # Genitive can be obl, especially with a preposition ("od čega se odnosi...")
                # But it is not guaranteed. It could be also an object.
                elsif($node->is_genitive())
                {
                    $node->set_deprel('obl');
                }
                # Dative can be obj, iobj or obl.
                elsif($node->is_dative())
                {
                    $node->set_deprel('obj');
                }
                elsif($node->is_locative())
                {
                    # There is at least one occurrence of "kojima" without preposition which should in fact be dative.
                    if(lc($node->form()) eq 'kojima' && scalar($node->children())==0)
                    {
                        $node->iset()->set('case', 'dat');
                        $node->set_deprel('obj'); ###!!! or iobj
                    }
                    else
                    {
                        $node->set_deprel('obl');
                    }
                }
                # Instrumental can be obl:agent of passives ("čime je potvrđena važeća prognoza").
                # But it is not guaranteed. It could be also an object.
                elsif($node->is_instrumental())
                {
                    $node->set_deprel('obl');
                }
            }
            elsif(any {$_->deprel() =~ m/^(cop|aux)$/} ($node->parent()->children()))
            {
                # There is at least one occurrence of "kojima" without preposition which should in fact be dative.
                if(lc($node->form()) eq 'kojima' && $node->is_locative() && scalar($node->children())==0)
                {
                    $node->iset()->set('case', 'dat');
                }
                $node->set_deprel('nmod');
            }
        }
        # timove čiji će zadatak biti nadzor cijena
        # teams whose task will be to control price
        # We have mark(nadzor, čiji). We want det(zadatak, čiji).
        if($node->lemma() =~ m/^(čiji|koliki|koji)$/ && $node->deprel() eq 'mark')
        {
            # Remove punctuation, coordinators (", ali čije ...") and prepositions ("na čijem čelu").
            my @siblings = grep {$_->deprel() !~ m/^(punct|cc|case)$/} ($node->parent()->get_children({'ordered' => 1}));
            if(scalar(@siblings) >= 3 && $siblings[0] == $node && $siblings[1]->deprel() =~ m/^(aux|cop)/ && $siblings[2]->is_noun() &&
               $node->iset()->case() eq $siblings[2]->iset()->case() ||
               scalar(@siblings) >= 2 && $siblings[0] == $node && $siblings[1]->is_noun() &&
               $node->iset()->case() eq $siblings[1]->iset()->case() ||
               # Similar to the first one but not as restrictive: čiji se pripadnici... ("se" is obj, not aux).
               scalar(@siblings) >= 3 && $siblings[0] == $node && $siblings[2]->is_noun() &&
               $node->iset()->case() eq $siblings[2]->iset()->case())
            {
                $node->set_parent($siblings[2]);
                $node->set_deprel('det');
            }
            elsif($node->parent()->is_noun() && $node->iset()->case() eq $node->parent()->iset()->case())
            {
                $node->set_deprel('det');
            }
        }
        # uz njega možete obaviti (with him you can do)
        elsif($node->lemma() eq 'on' && $node->deprel() eq 'mark')
        {
            $node->set_deprel('obl');
        }
        # Individual annotation errors found in the data.
        my $spanstring = $self->get_node_spanstring($node);
        # whose seat is in Brussels
        if($spanstring =~ m/^, čije je sjedište u Bruxellesu$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[5]->set_parent($node->parent());
            $subtree[5]->set_deprel($node->deprel());
            $subtree[2]->set_parent($subtree[5]);
            $subtree[2]->set_deprel('cop');
            $subtree[3]->set_parent($subtree[5]);
            $subtree[3]->set_deprel('nsubj');
            $subtree[1]->set_parent($subtree[3]);
            $subtree[1]->set_deprel('det');
            $subtree[0]->set_parent($subtree[5]);
        }
        # like communities in which minority population dominates
        elsif($spanstring =~ m/^kako zajednice u kojima dominira manjinsko stanovništvo$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_parent($node->parent());
            $subtree[1]->set_deprel($node->deprel());
            $subtree[0]->set_parent($subtree[1]);
            $subtree[0]->set_deprel('mark');
            $subtree[4]->set_parent($subtree[1]);
            $subtree[4]->set_deprel('acl');
            $subtree[3]->set_parent($subtree[4]);
            $subtree[3]->set_deprel('obl');
        }
        # including one for best new artist of the year
        elsif($spanstring =~ m/^, među kojima i onu za najboljeg izvođača/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_parent($node->parent());
            $subtree[4]->set_deprel('conj'); # originally: parataxis
            $subtree[2]->set_parent($subtree[4]);
            $subtree[2]->set_deprel('orphan');
        }
        ###!!! TEMPORARY HACK: THROW AWAY REMNANT BECAUSE WE CANNOT CONVERT IT.
        if($node->deprel() eq 'remnant')
        {
            #$node->set_deprel('dep:remnant');
        }
    }
}



#------------------------------------------------------------------------------
# Collects all nodes in a subtree of a given node. Useful for fixing known
# annotation errors, see also get_node_spanstring(). Returns ordered list.
#------------------------------------------------------------------------------
sub get_node_subtree
{
    my $self = shift;
    my $node = shift;
    my @nodes = $node->get_descendants({'add_self' => 1, 'ordered' => 1});
    return @nodes;
}



#------------------------------------------------------------------------------
# Collects word forms of all nodes in a subtree of a given node. Useful to
# uniquely identify sentences or their parts that are known to contain
# annotation errors. (We do not want to use node IDs because they are not fixed
# enough in all treebanks.) Example usage:
# if($self->get_node_spanstring($node) =~ m/^peça a URV em a sua mesada$/)
#------------------------------------------------------------------------------
sub get_node_spanstring
{
    my $self = shift;
    my $node = shift;
    my @nodes = $self->get_node_subtree($node);
    return join(' ', map {$_->form() // ''} (@nodes));
}



1;

=over

=item Treex::Block::HamleDT::HR::FixUD

This is a temporary block that should fix selected known problems in the Croatian UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

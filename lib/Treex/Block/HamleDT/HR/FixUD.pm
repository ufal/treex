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
            elsif($lemma =~ m/^(kakav|koji)$/)
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
        if($node->is_participle())
        {
            # Is there an aux:pass, expl:pass, nsubj:pass or csubj:pass child?
            my @passchildren = grep {$_->deprel() =~ m/:pass$/} ($node->children());
            if(scalar(@passchildren) >= 1)
            {
                $iset->set('voice' => 'pass');
            }
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
        if($node->lemma() =~ m/^(tko|što|kakav|koji)$/ && $node->deprel() eq 'mark' && ($node->parent()->is_verb() || $node->parent()->is_participle()))
        {
            if($node->is_nominative())
            {
                $node->set_deprel('nsubj');
            }
            elsif($node->is_accusative())
            {
                $node->set_deprel('obj');
            }
            # Genitive can be obl, especially with a preposition ("od čega se odnosi...")
            # But it is not guaranteed. It could be also an object.
            elsif($node->is_genitive())
            {
                $node->set_deprel('obl');
            }
            elsif($node->is_locative())
            {
                $node->set_deprel('obl');
            }
            # Instrumental can be obl:agent of passives ("čime je potvrđena važeća prognoza").
            # But it is not guaranteed. It could be also an object.
            elsif($node->is_instrumental())
            {
                $node->set_deprel('obl');
            }
        }
        # timove čiji će zadatak biti nadzor cijena
        # teams whose task will be to control price
        # We have mark(nadzor, čiji). We want det(zadatak, čiji).
        elsif($node->lemma() eq 'čiji' && $node->deprel() eq 'mark')
        {
            my @siblings = $node->parent()->get_children({'ordered' => 1});
            if(scalar(@siblings) >= 3 && $siblings[0] == $node && $siblings[1]->deprel() =~ m/^aux/ && $siblings[2]->is_noun() &&
               $node->iset()->case() eq $siblings[2]->iset()->case())
            {
                $node->set_parent($siblings[2]);
                $node->set_deprel('det');
            }
        }
        ###!!! TEMPORARY HACK: THROW AWAY REMNANT BECAUSE WE CANNOT CONVERT IT.
        if($node->deprel() eq 'remnant')
        {
            $node->set_deprel('dep:remnant');
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

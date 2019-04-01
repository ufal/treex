package Treex::Block::HamleDT::CS::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::SplitFusedWords';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        $self->fix_morphology($node);
        $self->classify_numerals($root);
    }
    # Do not call syntactic fixes from the previous loop. First make sure that
    # all nodes have correct morphology, then do syntax (so that you can rely
    # on the morphology you see at the parent node).
    foreach my $node (@nodes)
    {
        $self->fix_constructions($node);
    }
    $self->fix_jak_znamo($root);
    # It is possible that we changed the form of a multi-word token.
    # Therefore we must re-generate the sentence text.
    #$root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Fixes known issues in part-of-speech and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $node = shift;
    my $lform = lc($node->form());
    my $lemma = $node->lemma();
    my $iset = $node->iset();
    my $deprel = $node->deprel();
    # In PDT, the word "přičemž" ("and/where/while") is tagged as SCONJ but attached as Adv (advmod).
    # Etymologically, it is a preposition fused with a pronoun ("při+čemž"). We will re-tag it as adverb.
    if($lform eq 'přičemž')
    {
        $iset->set_hash({'pos' => 'adv', 'prontype' => 'rel'});
    }
    # Make sure that the UPOS tag still matches Interset features.
    $node->set_tag($node->iset()->get_upos());
}



#------------------------------------------------------------------------------
# Splits numeral types that have the same tag in the PDT tagset and the
# Interset decoder cannot distinguish them because it does not see the word
# forms.
#------------------------------------------------------------------------------
sub classify_numerals
{
    my $self  = shift;
    my $node  = shift;
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



#------------------------------------------------------------------------------
# Converts dependency relations from UD v1 to v2.
#------------------------------------------------------------------------------
sub fix_constructions
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $deprel = $node->deprel();
    # In "auch wenn", "wenn" is 'mark' or 'cc' and "auch" is wrongly attached as 'advmod' to "wenn".
    if($node->deprel() =~ m/^advmod(:|$)/ && $parent->deprel() =~ m/^(cc|mark)(:|$)/)
    {
        $parent = $parent->parent();
        $node->set_parent($parent);
    }
    if($node->is_pronoun() && $node->deprel() eq 'advmod')
    {
        $deprel = 'obl';
        $node->set_deprel($deprel);
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



1;

=over

=item Treex::Block::HamleDT::DE::FixUD

Czech-specific post-processing after the treebank has been converted from the
Prague style to Universal Dependencies. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::HamleDT::LT::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Base'; # provides get_node_spanstring()



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        #$self->fix_morphology($node);
        #$self->classify_numerals($node);
    }
    # Do not call syntactic fixes from the previous loop. First make sure that
    # all nodes have correct morphology, then do syntax (so that you can rely
    # on the morphology you see at the parent node).
    # Some depictives in accusative with the conjunction "kaip" slipped through
    # the cracks as "objects" while they should be xcomp or advcl:pred.
    ###!!! Perhaps this should be fixed already when harmonizing the Prague
    ###!!! style (AtvV instead of Obj) but for now we do it here, it is simpler.
    $self->relabel_depictive_objects($root);
    foreach my $node (@nodes)
    {
        $self->identify_acl_relcl($node);
    }
    # It is possible that we changed the form of a multi-word token.
    # Therefore we must re-generate the sentence text.
    #$root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Some depictives in accusative with the conjunction "kaip" slipped through
# the cracks as "objects" while they should be xcomp or advcl:pred.
###!!! Perhaps this should be fixed already when harmonizing the Prague
###!!! style (AtvV instead of Obj) but for now we do it here, it is simpler.
#------------------------------------------------------------------------------
sub relabel_depictive_objects
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^obj(:|$)/)
        {
            my $jako = any {$_->lemma() eq 'kaip'} ($node->children());
            if($jako)
            {
                $node->set_deprel('advcl:pred');
            }
            else
            {
            }
        }
    }
    # Do this only after all "jako" nominals have been resolved. Otherwise we
    # would count them when looking for possible other objects, although they
    # no longer pose a problem.
    foreach my $node (@nodes)
    {
        # In "činilo jeho samotu docela zábavnou", the noun "samotu"
        # is a direct object but the adjective "zábavnou" should be
        # annotated as a resultative (xcomp). However, we cannot
        # distinguish resultatives from depictives, as the decision
        # depends on the semantics of the verb. Therefore, we make them
        # all optional depictives for the time being. ###!!!
        if($node->deprel() =~ m/^obj(:|$)/ && $node->is_adjective() && !$node->is_pronominal())
        {
            my $other_objects = any {$_->deprel() =~ m/^obj(:|$)/} ($node->get_siblings());
            if($other_objects)
            {
                $node->set_deprel('advcl:pred'); ###!!! or xcomp
            }
        }
    }
    ###!!! The rest also serves the goal of removing superfluous objects but it
    ###!!! is no longer about secondary predication, so it should ultimately
    ###!!! end up in a separate function and maybe block. But then we would
    ###!!! also have to make sure that it does not interfere with the things we
    ###!!! do above with depictives.
    foreach my $node (@nodes)
    {
        # A few Czech verbs allow two accusative objects: "učit", "naučit",
        # "vyučovat", "odnaučit", "stát" (někoho něco). One of the objects
        # should be 'iobj', the other 'obj'. We want to make the "recipient"
        # (or beneficiary, or simply the participant closest to such roles)
        # the indirect object, but we cannot identify them automatically and
        # reliably. Picking personal pronouns (especially 1st and 2nd person)
        # as the recipient should work but it would not resolve everything.
        ###!!! For now, simply keep the last one as 'obj', make the others 'iobj'.
        my @objects = grep {$_->deprel() =~ m/^obj(:|$)/} ($node->children({'ordered' => 1}));
        if(scalar(@objects) > 1)
        {
            for(my $i = 0; $i < $#objects; $i++)
            {
                $objects[$i]->set_deprel('iobj');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Figures out whether an adnominal clause is a relative clause, and changes the
# relation accordingly.
#------------------------------------------------------------------------------
sub identify_acl_relcl
{
    my $self = shift;
    my $node = shift;
    return unless($node->deprel() =~ m/^acl(:|$)/);
    # Look for a relative pronoun or a subordinating conjunction. The first
    # such word from the left is the one that matters. However, it is not
    # necessarily the first word in the subtree: there can be punctuation and
    # preposition. The relative pronoun can be even the root of the clause,
    # i.e., the current node, if the clause is copular.
    # Specifying (first|last|preceding|following)_only implies ordered.
    my @subordinators = grep {$_->is_subordinator() || $_->is_relative()} ($node->get_descendants({'preceding_only' => 1, 'add_self' => 1}));
    return unless(scalar(@subordinators) > 0);
    my $subordinator = $subordinators[0];
    # If there is a subordinating conjunction, the clause is not relative even
    # if there is later also a relative pronoun.
    return if($subordinator->is_subordinator() || $subordinator->deprel() =~ m/^mark(:|$)/);
    # Many words can be both relative and interrogative and the two functions are
    # not disambiguated in morphological features, i.e., they get PronType=Int,Rel
    # regardless of context. We only want to label a clause as relative if there
    # is coreference between the relative word and the nominal modified by the clause.
    # For example, 1. is a relative clause and 2. is not:
    # 1. otázka, která se stále vrací (question that recurs all the time)
    # 2. otázka, která strana vyhraje volby (question which party wins the elections)
    # Certain interrogative-relative words seem to never participate in a proper
    # relative clause.
    return if($subordinator->lemma() =~ m/^(kaip)$/);
    # The interrogative-relative adverb "proč" ("why") could be said to corefer with a few
    # selected nouns but not with others. Note that the parent can be also a
    # pronoun (typically the demonstrative/correlative "to"), which is also OK.
    my $parent = $node->parent();
    return if($subordinator->lemma() eq 'kodėl' && $parent->lemma() !~ m/^(důvod|příčina|záminka|ten|to)$/);
    # An incomplete list of nouns that can occur with an adnominal clause which
    # resembles but is not a relative clause. Of course, all of them can also be
    # modified by a genuine relative clause.
    my $badnouns = 'argument|dotaz|důkaz|kombinace|kritérium|možnost|myšlenka|nařízení|nápis|názor|otázka|pochopení|pochyba|pomyšlení|pravda|problém|projekt|průzkum|představa|přehled|příklad|rada|údaj|úsloví|uvedení|východisko|zkoumání|způsob';
    # The interrogative-relative pronouns "kdo" ("who") and "co" ("what") usually
    # occur with one of the "bad nouns". We will keep only the remaining cases
    # where they occur with a different noun or pronoun. This is an approximation
    # that will not always give correct results.
    return if($subordinator->lemma() =~ m/^(kas|kelintas|katras)$/ && $parent->lemma() =~ m/^($badnouns)$/);
    # The relative words are expected only with certain grammatical relations.
    # The acceptable relations vary depending on the depth of the relative word.
    # In depth 0, the relation is acl, which is not acceptable anywhere deeper.
    my $depth = 0;
    for(my $i = $subordinator; $i != $node; $i = $i->parent())
    {
        $depth++;
    }
    return if($depth > 0 && $subordinator->lemma() =~ m/^(kas|kuris|koks)$/ && $subordinator->deprel() !~ m/^(nsubj|obj|iobj|obl|nmod|det)(:|$)/);
    return if($subordinator->lemma() =~ m/^(kur|kada|kaip|kodėl)$/ && $subordinator->deprel() !~ m/^advmod(:|$)/);
    ###!!! We do not rule out the "bad nouns" for the most widely used relative
    ###!!! word "kuris" ("which"). However, this word can actually occur in
    ###!!! fake relative (interrogative) clauses. We may want to check the bad
    ###!!! nouns and agreement in gender and number; if the relative word agrees
    ###!!! with the bad noun, the clause is recognized as relative, otherwise
    ###!!! it is not.
    $node->set_deprel('acl:relcl');
}



1;

=over

=item Treex::Block::HamleDT::LT::FixUD

Lithuanian-specific post-processing after the treebank has been converted from the
Prague style to Universal Dependencies. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::HamleDT::UdepToPrague;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::UDToPrague;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'mul::uposf',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads a UD tree, converts universal tags and features to Interset, converts
# dependency relations, transforms tree to adhere to the HamleDT / Prague
# guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);

    # Adjust the tree structure.
    my $builder = new Treex::Tool::PhraseBuilder::UDToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    ###!!! Prepositions and copulas up – this should be solved by the phrase builder!
    $self->raise_function_words($root);
    # Make sure that all nodes have known deprels.
    $self->check_deprels($root);
    return;
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://universaldependencies.org/
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        # Convert the labels.
        # Language-specific subtypes are treated as the main relations, e.g. "acl:relcl" is identical to "acl".
        # Adnominal (attributive) clause.
        if($deprel =~ m/^acl(:|$)/)
        {
            $deprel = 'Atr';
        }
        # Adverbial clause that functions as a modifier (adjunct).
        elsif($deprel =~ m/^advcl(:|$)/)
        {
            $deprel = 'Adv';
        }
        # Adverb that functions as adverbial modifier.
        elsif($deprel =~ m/^advmod(:|$)/)
        {
            $deprel = 'Adv';
        }
        # Adjectival modifier of a noun.
        elsif($deprel =~ m/^amod(:|$)/)
        {
            $deprel = 'Atr';
        }
        # Apposition.
        elsif($deprel =~ m/^appos(:|$)/)
        {
            $deprel = 'Apposition';
        }
        # Auxiliary verb attached to the main verb.
        elsif($deprel =~ m/^aux(pass)?(:|$)/)
        {
            $deprel = 'AuxV';
        }
        # Preposition attached to its nominal argument is labeled case.
        elsif($deprel =~ m/^case(:|$)/)
        {
            $deprel = 'AuxP';
        }
        # Coordinating conjunction.
        elsif($deprel =~ m/^cc(:|$)/)
        {
            $deprel = 'AuxY';
        }
        # Clausal complement of a predicate.
        elsif($deprel =~ m/^ccomp(:|$)/)
        {
            $deprel = 'Obj';
        }
        # Non-head part of compound expression.
        elsif($deprel =~ m/^compound(:|$)/)
        {
            $deprel = 'Atr';
        }
        # Non-first conjunct is attached to the first conjunct as conj.
        elsif($deprel =~ m/^conj(:|$)/)
        {
            $deprel = 'CoordArg';
        }
        # Copula is attached to the nominal predicate.
        elsif($deprel =~ m/^cop(:|$)/)
        {
            $deprel = 'Cop';
        }
        # Clausal subject.
        elsif($deprel =~ m/^csubj(pass)?(:|$)/)
        {
            $deprel = 'Sb';
        }
        # Uncategorized dependency.
        elsif($deprel =~ m/^dep(:|$)/)
        {
            $deprel = 'ExD'; ###!!!???
        }
        # Determiner attached to a noun.
        elsif($deprel =~ m/^det(:|$)/)
        {
            # Note that HamleDT never set the AuxA label but it may be needed when the Prague annotation is used as input for tectogrammatic analysis.
            $deprel = $node->iset()->is_article() ? 'AuxA' : 'Atr';
        }
        # Discourse particles etc.
        elsif($deprel =~ m/^discourse(:|$)/)
        {
            $deprel = 'AuxZ'; ###!!! or maybe AuxO? But sometimes they may not be redundant, and AuxO is for redundant items.
        }
        # Dislocated constituent that cannot be plugged into a normal syntactic structure.
        elsif($deprel =~ m/^dislocated(:|$)/)
        {
            $deprel = 'ExD'; ###!!!???
        }
        # Direct object of verb. (If there is one object, it is direct. If there are more, one of them is direct and the rest are indirect.)
        elsif($deprel =~ m/^dobj(:|$)/)
        {
            $deprel = 'Obj';
        }
        # Expletive is used for various phenomena, usually pronouns. In Czech it covers reflexive pronouns of inherently reflexive verbs, which is labeled AuxT in PDT.
        elsif($deprel =~ m/^expl(:|$)/)
        {
            $deprel = 'AuxT';
        }
        # Non-first word in a foreign segment in case of code switching.
        elsif($deprel =~ m/^foreign(:|$)/)
        {
            $deprel = 'Atr';
        }
        # Two parts of what should be one word. May occur in poorly edited text.
        elsif($deprel =~ m/^goeswith(:|$)/)
        {
            $deprel = 'Atr';
        }
        # Indirect object of verb. (If there is one object, it is direct. If there are more, one of them is direct and the rest are indirect.)
        elsif($deprel =~ m/^iobj(:|$)/)
        {
            $deprel = 'Obj';
        }
        # List of items where analyzing them as coordination seems less suitable.
        elsif($deprel =~ m/^list(:|$)/)
        {
            $deprel = 'CoordArg';
        }
        # Mark is typically used for subordinating conjunctions attached to the predicate of the subordinate clause.
        elsif($deprel =~ m/^mark(:|$)/)
        {
            $deprel = 'AuxC';
        }
        # Multi-word expression.
        elsif($deprel =~ m/^mwe(:|$)/)
        {
            # A head-first phrase with all dependents labeled Atr is the behavior closest to PDT.
            ###!!! However, in the case of multi-word prepositions, it should be AuxP.
            ###!!! We may want to add MWE as a new relation to the Prague style.
            $deprel = 'Atr';
        }
        # Non-first part of a multi-word name, if no normal head-dependent relation can be recognized.
        elsif($deprel =~ m/^name(:|$)/)
        {
            $deprel = 'Atr';
        }
        # Negation.
        elsif($deprel =~ m/^neg(:|$)/)
        {
            $deprel = 'Neg';
        }
        # Noun phrase that functions as an adverbial modifier.
        elsif($deprel =~ m/^nmod(:|$)/)
        {
            $deprel = 'Adv';
        }
        # Noun phrase that functions as subject.
        elsif($deprel =~ m/^nsubj(pass)?(:|$)/)
        {
            $deprel = 'Sb';
        }
        # Numerical modifier (cardinal number modifying a counted noun).
        elsif($deprel =~ m/^nummod(:|$)/)
        {
            $deprel = 'Atr';
        }
        # Parataxis. Loosely attached clause.
        elsif($deprel =~ m/^parataxis(:|$)/)
        {
            $deprel = 'ExD';
        }
        # Punctuation.
        elsif($deprel =~ m/^punct(:|$)/)
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }
        # Remnant after ellipsis in coordination. This relation will be removed in UD v2 but it may occur in older data.
        elsif($deprel =~ m/^remnant(:|$)/)
        {
            $deprel = 'ExD';
        }
        # Repair in spoken language.
        elsif($deprel =~ m/^reparandum(:|$)/)
        {
            ###!!! The Prague annotation style does not have any similar relation.
            $deprel = 'ExD';
        }
        # Root token, child of the artificial root node. Typically the main predicate.
        elsif($deprel =~ m/^root(:|$)/)
        {
            ###!!! It should be ExD if the root token is not verb. But we cannot
            ###!!! query the part of speech now because the root predicate may
            ###!!! be an adjective or noun with copula, later we will raise the
            ###!!! copula and its relation will be Pred.
            $deprel = 'Pred';
        }
        # Clausal complement that does not have its independent subject.
        # It is controlled by a higher clause and its subject is either subject or object of the higher clause.
        elsif($deprel =~ m/^xcomp(:|$)/)
        {
            $deprel = 'Obj';
        }
        # Vocative noun phrase in second-person clauses.
        elsif($deprel =~ m/^vocative(:|$)/)
        {
            # ExD is the standard treatment of vocatives in PDT.
            $deprel = 'ExD';
        }
        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# Finds function words that are attached as leaves and should become heads:
#   - prepositions (AuxP)
#   - copula verbs (Cop)
# Reattaches the nodes as heads of the phrase. If there are both a preposition
# and a copula in one phrase (e.g. "A encomenda está em o armazém."), the
# function proceeds left-to-right, i.e. the copula will govern the preposition.
#------------------------------------------------------------------------------
sub raise_function_words
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Cop' && $node->is_leaf() && !$node->is_member())
        {
            my $parent = $node->parent();
            if(defined($parent))
            {
                my $grandparent = $parent->parent();
                if(defined($grandparent))
                {
                    $node->set_parent($grandparent);
                    $node->set_deprel($parent->deprel());
                    $node->set_is_member($parent->is_member());
                    $parent->set_parent($node);
                    $parent->set_deprel('Pnom');
                    $parent->set_is_member(0);
                    # Find subject, if any (it is not forbidden to find even more (non-coordinate), although it would be strange).
                    my @subjects = grep {$_->get_real_afun() eq 'Sb'} $parent->children();
                    foreach my $subject (@subjects)
                    {
                        $subject->set_parent($node);
                    }
                    # Adverbial modifiers that appear before the copula should be attached to the copula.
                    if($node->ord() < $parent->ord())
                    {
                        my @premodifiers = grep {$_->ord() < $node->ord()} $parent->children();
                        foreach my $premod (@premodifiers)
                        {
                            $premod->set_parent($node);
                        }
                    }
                }
            }
        }
        elsif($node->deprel() eq 'AuxP' && $node->is_leaf() && !$node->is_member())
        {
            my $parent = $node->parent();
            if(defined($parent))
            {
                my $grandparent = $parent->parent();
                if(defined($grandparent))
                {
                    if(defined($grandparent->deprel()) && $grandparent->deprel() eq 'AuxP')
                    {
                        log_warn('Attaching a preposition under another preposition');
                    }
                    $node->set_parent($grandparent);
                    $parent->set_parent($node);
                    $node->set_is_member($parent->is_member());
                    $parent->set_is_member(0);
                }
            }
        }
    }
    return:
}



1;

=head1 NAME

Treex::Block::HamleDT::UdepToPrague

=head1 DESCRIPTION

Converts a Universal Dependencies treebank to the Prague style of HamleDT.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

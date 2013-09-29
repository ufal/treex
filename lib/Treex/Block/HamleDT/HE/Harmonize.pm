package Treex::Block::HamleDT::HE::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;

    my $a_root = $self->SUPER::process_zone($zone);
    # $self->restructure_coordination($a_root);
    $self->attach_final_punctuation_to_root($a_root);
    
    $self->check_afuns($a_root);

    return $a_root;
}

# Some of the dependencies in the Treebank are labeled. Specifically, dependency
# labels are used to mark Subjects (SUBJ), Objects (OBJ), and Complements (COM).
# Most other relations are marked with the generic “dep” label.
# TODO
my %deprel2afun = (

    # COMMON LABELS
    # =============
    
    # Subject
    SBJ => 'Sb',
    # Complement
    COM => 'Atv',
    # Object
    OBJ => 'Obj',
    # no info, but probably an adjective
    ADJ => 'Atr',
    # no info, but probably an adverb
    ADV => 'Adv',
    
    # HARDER LABELS
    # ===============

    # coordinated elements
    # (is_member=1)
    # Distinguish coordinated elements (CONJ) from the modifiers and arguments
    # of the coordinated structure (i.e. other children of the coordination
    # head).
    # TODO
    CONJ => 'Coord',
    
    # parts of multi-word expressions
    # first word is the head, following words form a chain
    # ???
    # use set_default_afun()
    # MW => 'Apos',
    
    # WEIRD LABELS
    # ============

    # generic label
    # Atr/Adv/???
    # use set_default_afun()
    # dep => 'Atr', 
    
    # MOD is used for general modifiers of nouns, adjectives, adverbs,
    # prepositional phrase (this info is NOT from Yoav, but from Mila)
    # ?? is there a difference from 'dep' ??
    # use set_default_afun()
    # MOD => 'Atr',

    # root of the tree (child of the technical root)
    # Pred/ExD
    # use set_default_afun()
    # ROOT => 'Pred',
    
    # pronominal suffixes
    # inflected preposition (וב⇒suffאוה ב “in-him” )
    prep_infl => 'AuxP',
    # inflected AT (direct object) marker (ונתוא⇒suffונחנא תא “AT-us”)
    # AT תא is the parent of the object it is marking (!)
    at_infl => 'AuxY',
    # inflected possessive (ילש⇒suffינא לש “of-I”/mine)
    pos_infl => 'AuxY',
    # inflected adverbs (ודוע⇒suffאוה דוע “while-he”) pos
    rb_infl => 'Adv',

    # mentioned but unseen in data:
    # PRN (Mark the beginnings of parentheticals and quotes)
);


sub deprel_to_afun {
    my $self   = shift;
    my $root   = shift;
    my @nodes  = $root->get_descendants();

    for my $node (@nodes) {
	    my $deprel = $node->conll_deprel;
	    my $parent = $node->get_parent();

        my $afun = $deprel2afun{$deprel};

        # TODO

        if ( defined $afun ) {
            $node->set_afun($afun);
        }
        else {
            $self->set_default_afun($node);
        }
    }
}

# TODO:
# Coordination
# The coordinating element is the head of the conjunction. In the event that
# there are several coordinating elements, the last one is chosen as the head
# of the others.
#
# The members of the coordination are marked by the CONJ label.
#
# TODO: run this before changing the afuns etc.
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    return 'not implemented';
}

1;

=head1 NAME 

Treex::Block::HamleDT::HE::Harmonize

=head1 DESCRIPTION

Convert Hebrew treebank dependency trees to HamleDT style.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


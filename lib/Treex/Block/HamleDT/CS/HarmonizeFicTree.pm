package Treex::Block::HamleDT::CS::HarmonizeFicTree;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'cs::pdt',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

has change_bundle_id => (is=>'ro', isa=>'Bool', default=>1, documentation=>'use id of a-tree roots as the bundle id');

#------------------------------------------------------------------------------
# Reads the Czech tree and transforms it to adhere to the HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
}



#------------------------------------------------------------------------------
# Different source treebanks may use different attributes to store information
# needed by Interset drivers to decode the Interset feature values. By default,
# the CoNLL 2006 fields CPOS, POS and FEAT are concatenated and used as the
# input tag. If the morphosyntactic information is stored elsewhere (e.g. in
# the tag attribute), the Harmonize block of the respective treebank should
# redefine this method. Note that even CoNLL 2009 differs from CoNLL 2006.
#------------------------------------------------------------------------------
sub get_input_tag_for_interset
{
    my $self   = shift;
    my $node   = shift;
    return $node->tag();
}



#------------------------------------------------------------------------------
###!!! DUPLICATE, SAME METHOD IS IN CS::HARMONIZE.PM! THEY SHOULD BE INHERITED FROM ONE PLACE!
# Adds Interset features that cannot be decoded from the PDT tags but they can
# be inferred from lemmas and word forms. This method is called from
# SUPER->process_zone().
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    # We must first normalize the lemmas because many subsequent rules depend on them.
###!!! NOT IN FICTREE DATA!    $self->remove_features_from_lemmas($root);
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $lemma = $node->lemma();
        # Fix Interset features of pronominal words.
        if($node->is_pronominal())
        {
            # Indefinite pronouns and determiners cannot be distinguished by their PDT tag (PZ*).
            if($lemma =~ m/^((ně|lec|ledas?|kde|bůhví|kdoví|nevím|málo|sotva)?(kdo|cos?)(si|koliv?)?|nikdo|nic)$/)
            {
                $node->iset()->set('pos', 'noun');
            }
            elsif($lemma =~ m/(^(jaký|který)|(jaký|který)$|^(každý|všechen|sám|žádný)$)/)
            {
                $node->iset()->set('pos', 'adj');
            }
            # Pronouns čí, něčí, čísi, číkoli, ledačí, kdečí, bůhvíčí, nevímčí, ničí should have Poss=Yes.
            elsif($lemma =~ m/^((ně|lec|ledas?|kde|bůhví|kdoví|nevím|ni)?čí|čí(si|koliv?))$/)
            {
                $node->iset()->set('pos', 'adj');
                $node->iset()->set('poss', 'poss');
            }
            # Pronoun (determiner) "sám" is difficult to classify in the traditional Czech system but in UD v2 we now have the prontype=emph, which is quite suitable.
            if($lemma eq 'sám')
            {
                $node->iset()->set('prontype', 'emp');
            }
            # Pronominal numerals are all treated as combined demonstrative and indefinite, because the PDT tag is only one.
            # But we can distinguish them by the lemma.
            if($lemma =~ m/^kolikráte?$/)
            {
                $node->iset()->set('prontype', 'int|rel');
            }
            elsif($lemma =~ m/^((po)?((ně|kdoví|bůhví|nevím)kolik|(ne|pře)?(mnoho|málo)|(nej)?(více?|méně|míň)|moc|mó+c|hodně|bezpočtu|nespočet|nesčíslně)(átý|áté|erý|ero|k?ráte?)?)$/)
            {
                $node->iset()->set('prontype', 'ind');
            }
            elsif($lemma =~ m/^tolik(ráte?)?$/)
            {
                $node->iset()->set('prontype', 'dem');
            }
        }
        # Pronominal adverbs.
        if($node->is_adverb())
        {
            if($lemma =~ m/^(kde|kam|odkud|kudy|kdy|odkdy|dokdy|jak|proč)$/)
            {
                $node->iset()->set('prontype', 'int|rel');
            }
            elsif($lemma =~ m/^((ně|ledas?|málo|kde|bůhví|nevím)(kde|kam|kudy|kdy|jak)|(od|do)ně(kud|kdy)|(kde|kam|odkud|kudy|kdy|jak)(si|koliv?))$/)
            {
                $node->iset()->set('prontype', 'ind');
            }
            elsif($lemma =~ m/^(tady|zde|tu|tam|tamhle|onam|odsud|odtud|odtamtud|teď|nyní|tehdy|tentokráte?|tenkráte?|odtehdy|dotehdy|dosud|tak|proto)$/)
            {
                $node->iset()->set('prontype', 'dem');
            }
            elsif($lemma =~ m/^(všude|odevšad|všudy|vždy|odevždy|odjakživa|navždy)$/)
            {
                $node->iset()->set('prontype', 'tot');
            }
            elsif($lemma =~ m/^(nikde|nikam|odnikud|nikudy|nikdy|odnikdy|donikdy|nijak)$/)
            {
                $node->iset()->set('prontype', 'neg');
            }
        }
        # Passive participles should be adjectives both in their short (predicative)
        # and long (attributive) form. Now the long forms are adjectives and short
        # forms are verbs (while the same dichotomy of non-verbal adjectives, such as
        # starý-stár, is kept within adjectives).
        if($node->is_verb() && $node->is_participle() && $node->iset()->is_passive())
        {
            $node->iset()->set('pos', 'adj');
            $node->iset()->set('variant', 'short');
            # That was the easy part. But we must also change the lemma.
            # nést-nesen-nesený, brát-brán-braný, mazat-mazán-mazaný, péci-pečen-pečený, zavřít-zavřen-zavřený, tisknout-tištěn-tištěný, minout-minut-minutý, začít-začat-začatý,
            # krýt-kryt-krytý, kupovat-kupován-kupovaný, prosit-prošen-prošený, trpět-trpěn-trpěný, sázet-sázen-sázený, dělat-dělán-dělaný
            my $form = lc($node->form());
            # Remove gender/number morpheme if present.
            $form =~ s/[aoiy]$//;
            # Stem vowel change "á" to "a".
            $form =~ s/án$/an/;
            # Add the ending of masculine singular nominative long adjectives.
            $form .= 'ý';
            $node->set_lemma($form);
        }
    }
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        # The _Co suffix signals conjuncts.
        # The _Ap suffix signals members of apposition.
        # We will later reshape appositions but the routine will expect is_member set.
        if($deprel =~ s/_(Co|Ap)$//i)
        {
            $node->set_is_member(1);
            # There are nodes that have both _Ap and _Co but we have no means of representing that.
            # Remove the other suffix if present.
            $deprel =~ s/_(Co|Ap)$//i;
        }
        # Convert the _Pa suffix to the is_parenthesis_root flag.
        if($deprel =~ s/_Pa$//i)
        {
            $node->set_is_parenthesis_root(1);
        }
        # combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $deprel =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $deprel = 'Atr';
        }
        # Annotation error (one occurrence in PDT 3.0): Coord must not be leaf.
        if($deprel eq 'Coord' && $node->is_leaf() && $node->parent()->is_root())
        {
            $deprel = 'ExD';
        }
        $node->set_deprel($deprel);
    }
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real deprel. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->pdt_to_treex_is_member_conversion($root);
}



1;

=over

=item Treex::Block::HamleDT::CS::HarmonizeFicTree

Converts FicTree, the Czech Fiction Treebank, to the style of HamleDT (Prague).
There are slight differences to how Prague Dependency Treebank is converted.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

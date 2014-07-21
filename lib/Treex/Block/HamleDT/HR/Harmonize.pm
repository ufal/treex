package Treex::Block::HamleDT::HR::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'hr::multext',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Croatian tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->mark_deficient_clausal_coordination($root);
    $self->fix_compound_prepositions($root);
    $self->fix_compound_conjunctions($root);
    $self->fix_other($root);
    $self->check_afuns($root);
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
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;
        # The syntactic tagset of SETimes.HR has been apparently influenced by PDT.
        # For most part it should suffice to rename the tags (or even leave them as they are).
        if($deprel eq 'Ap')
        {
            $afun = 'Apposition';
        }
        # Rather than the verbal attribute (doplnìk) of PDT, this seems to apply to infinitives attached to modal verbs.
        # However, there are other cases as well.
        elsif($deprel eq 'Atv')
        {
            $afun = 'NR';
            # Infinitive attached to modal verb.
            # Example (Croatian and Czech with PDT annotation):
            # kažu/Pred da/Sub mogu/Pred iskoristiti/Atv
            # øíkají/Pred že/AuxC mohou/Obj využít/Obj
            # they-say that they-can exploit
            if($node->is_infinitive() && $parent->is_verb())
            {
                $afun = 'Obj';
            }
            # Atv also occurred at a participial adjective modifying a noun:
            # 600 milijuna eura prebaèenih/Atv u banke
            elsif($node->is_adjective() && $parent->is_noun())
            {
                $afun = 'Atr';
            }
            # Prepositional phrase loosely attached to a participial adjective.
            # proces bio prenagljen bez/Prep plana/Atv za gospodarski razvoj
            elsif($node->is_noun() && $parent->is_adposition() && $parent->parent()->is_adjective())
            {
                $afun = 'Adv';
            }
        }
        # Reflexive pronoun/particle 'se', attached to verb.
        # Negative particle 'ne', attached to verb.
        # Auxiliary verb, e.g. 'sam' in 'Nadao sam se da' (Doufal jsem, že).
        elsif($deprel eq 'Aux')
        {
            # Auxiliary verb "biti" = "to be".
            # Auxiliary verb "htjeti" = "to want to".
            if($node->lemma() =~ m/^(biti|htjeti)$/)
            {
                $afun = 'AuxV';
            }
            # Reflexive pronoun "se" = "oneself".
            elsif($node->lemma() eq 'sebe')
            {
                $afun = 'AuxT';
            }
            # Negative particle "ne" = "not".
            elsif($node->lemma() eq 'ne')
            {
                $afun = 'Neg';
            }
            # Question particle "li":
            # Želite li da se zakon poštuje?
            # Do you want the law to be respected?
            elsif($node->lemma() eq 'li')
            {
                # HamleDT does not have a fitting dependency label. Should we create a new one, e.g. AuxQ?
                # We do not use 'AuxT' because this particle is not lexically bound to particular verbs.
                # We use 'AuxR', although in PDT it has a specific use different from this one.
                $afun = 'AuxR';
            }
        }
        elsif($deprel eq 'Co')
        {
            $afun = 'Coord';
            $node->wild()->{coordinator} = 1;
            ###!!! We must reconstruct conjuncts, they are not marked.
        }
        elsif($deprel eq 'Elp')
        {
            $afun = 'ExD';
        }
        # Also decomposed compound preposition (001#22):
        # These will be left unchanged (i.e. labeled 'Oth') and later fixed in targeted methods.
        # s obzirom da = s ohledem na to, že
        # osim toga = kromì toho
        elsif($deprel eq 'Oth')
        {
            if($node->is_conjunction())
            {
                # Coordinating conjunction at the beginning of the sentence should be analyzed as heading deficient clausal coordination.
                # We will now only change afun to 'Coord'; the rest will be done later by $self->mark_deficient_clausal_coordination().
                if($node->ord()==1)
                {
                    $afun = 'Coord';
                }
                # There are other occurrences of leaf conjunctions that actually do not coordinate anything.
                # Example: , a koje kosovska vlada ne koristi
                else
                {
                    $afun = 'AuxY';
                }
            }
            # Intensifying or emphasizing particles, adverbs etc.
            # Example: barem/Oth na papiru = alespoò na papíøe
            # Example: drugi ne dobivaju gotovo/Oth ništa = jiní nedostanou témìø nic
            # Example: i/TT/Oth etnièka komponenta = i etnická složka
            elsif(($node->is_adverb() || $node->is_particle()) &&
                  ($parent->is_adposition() || $parent->is_noun()) &&
                  $parent->ord() > $node->ord())
            {
                $afun = 'AuxZ';
            }
            # Other occurrences of the particle "i" should also qualify as AuxZ.
            elsif($node->form() eq 'i' && $node->is_particle())
            {
                $afun = 'AuxZ';
            }
            # Adverbial modifier / attribute.
            # Example: desetljeæe kasnije/Oth = a decade later ... should be attribute because its parent is noun.
            # vrlo èesto = velmi èasto = very often ... should be adverbial
            elsif($node->is_adverb())
            {
                if($parent->is_noun())
                {
                    $afun = 'Atr';
                }
                else
                {
                    $afun = 'Adv';
                }
            }
            # The conjunction "kao" = "as" is often attached as a leaf to the noun phrase it introduces.
            # Example: izgleda kao odlièna ideja = vypadá jako skvìlý nápad
            elsif($node->lemma() eq 'kao' && scalar($node->children())==0)
            {
                $afun = 'AuxY';
            }
            # bilo/Oth koja = jakákoli ("koli jaká") = any
            elsif($node->form() eq 'bilo' && $parent->lemma() eq 'koji')
            {
                $afun = 'Atr';
            }
        }
        elsif($deprel eq 'Prep')
        {
            $afun = 'AuxP';
        }
        elsif($deprel eq 'Punc')
        {
            if($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }
        elsif($deprel eq 'Sub')
        {
            $afun = 'AuxC';
        }
        # Set the (possibly changed) afun back to the node.
        $node->set_afun($afun);
    }
}

#------------------------------------------------------------------------------
# Restructures and relabels compound prepositions, e.g. "s obzirom" ("with the
# perspective that"), "osim toga" ("besides that").
#------------------------------------------------------------------------------
sub fix_compound_prepositions
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->is_preposition() && $node->afun() eq 'Oth' && scalar($node->children())==0)
        {
            my $parent = $node->parent();
            if(($parent->is_noun() || $parent->is_adjective()) && $parent->afun() eq 'Oth' && scalar($parent->children())==1)
            {
                my $grandparent = $parent->parent();
                if(!$grandparent->is_root())
                {
                    my $ggparent = $grandparent->parent();
                    $node->set_parent($ggparent);
                    $node->set_afun('AuxP');
                    $parent->set_parent($node);
                    if($ggparent->is_noun())
                    {
                        $parent->set_afun('Atr');
                    }
                    else
                    {
                        $parent->set_afun('Adv');
                    }
                    $grandparent->set_parent($parent);
                }
            }
            # Unfortunately the analyses are not consistent.
            # I saw "da ( obzirom ( s ) )" (the version handled above)
            # but I also saw "da ( s , obzirom )".
            else
            {
                my $rn = $node->get_right_neighbor();
                if(defined($rn) && $rn->form() eq 'obzirom' && $rn->afun() eq 'Oth' && scalar($rn->children())==0)
                {
                    my $grandparent = $parent->parent();
                    if(defined($grandparent))
                    {
                        $node->set_parent($grandparent);
                        $node->set_afun('AuxP');
                        $rn->set_parent($node);
                        if($grandparent->is_noun())
                        {
                            $rn->set_afun('Atr');
                        }
                        else
                        {
                            $rn->set_afun('Adv');
                        }
                        $parent->set_parent($rn);
                    }
                }
                # "nakon što" ("after") is not exactly a compound preposition but it can be also fixed here.
                # Note that we have verified that the current node is a preposition attached as a leaf, labeled 'Oth'.
                # We should also require that its parent lies to the right because we are going to make the parent a child of the preposition.
                elsif($parent->ord() > $node->ord())
                {
                    my $grandparent = $parent->parent();
                    if(defined($grandparent))
                    {
                        $node->set_parent($grandparent);
                        $node->set_afun('AuxP');
                        $parent->set_parent($node);
                    }
                }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Restructures and relabels compound conjunctions, e.g. "bilo-ili" ("either-
# or").
#------------------------------------------------------------------------------
sub fix_compound_conjunctions
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->form() eq 'bilo' && $node->afun() eq 'Oth' && scalar($node->children())==0)
        {
            my $parent = $node->parent();
            if(!$parent->is_root())
            {
                my $grandparent = $parent->parent();
                if($grandparent->form() eq 'ili')
                {
                    $node->set_parent($grandparent);
                    $node->set_afun('AuxY');
                }
            }
        }
        # kao i = jako i = as also
        # kao should be labeled AuxY and as such it should not have children.
        # i should be labeled AuxZ and instead of kao, it should be attached to kao's parent.
        elsif($node->form() eq 'i' && $node->afun() eq 'AuxZ' && $node->parent()->form() eq 'kao')
        {
            my $parent = $node->parent();
            my $grandparent = $parent->parent();
            $node->set_parent($grandparent);
        }
    }
}

#------------------------------------------------------------------------------
# Restructures and relabels various other phenomena.
#------------------------------------------------------------------------------
sub fix_other
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        if($node->is_numeral() && $node->afun() eq 'Oth' && $parent->form() =~ m/^gotovo$/i)
        {
            my $grandparent = $parent->parent();
            if(defined($grandparent))
            {
                $node->set_parent($grandparent);
                $node->set_afun('Atr');
                $parent->set_parent($node);
                $parent->set_afun('Atr');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HR::Harmonize

Converts SETimes.HR (Croatian) trees from their original annotation style
to the style of HamleDT (Prague).

The structure of the trees is apparently inspired by the PDT guidelines and
it should not require much effort to adjust it. Some syntactic tags (dependency
relation labels, analytical functions) have different names or have been
merged. This block will rename them back.

Morphological tags will be decoded into Interset and also converted to the
15-character positional tags of PDT.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

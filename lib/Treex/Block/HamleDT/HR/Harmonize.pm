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
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;
        # The syntactic tagset of SETimes.HR has been apparently influenced by PDT.
        # For most part it should suffice to rename the tags (or even leave them as they are).
        if($deprel eq 'Ap')
        {
            $afun = 'Apposition';
        }
        # Rather than the verbal attribute (doplnìk) of PDT, this seems to apply to infinitives attached to modal verbs.
        # Those would be labeled 'Obj' in PDT.
        # Example (Croatian and Czech with PDT annotation):
        # kažu/Pred da/Sub mogu/Pred iskoristiti/Atv
        # øíkají/Pred že/AuxC mohou/Obj využít/Obj
        # they-say that they-can exploit
        elsif($deprel eq 'Atv')
        {
            ###!!! Obj
            $afun = 'NR';
        }
        # Reflexive pronoun/particle 'se', attached to verb.
        # Negative particle 'ne', attached to verb.
        # Auxiliary verb, e.g. 'sam' in 'Nadao sam se da' (Doufal jsem, že).
        elsif($deprel eq 'Aux')
        {
            ###!!! AuxV AuxT AuxR Adv
            if($node->lemma() eq 'biti')
            {
                $afun = 'AuxV';
            }
            elsif($node->lemma() eq 'sebe')
            {
                $afun = 'AuxT';
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
        # Oth can be AuxZ:
        # barem na papiru = alespoò na papíøe
        # Also subordinating conjunction attached as a leaf:
        # izgleda kao odlièna ideja = vypadá jako skvìlý nápad
        # Also adverbial:
        # desetljeæe kasnije/Oth = a decade later
        # Also decomposed complex preposition (001#22):
        # s obzirom da = s ohledem na to, že
        elsif($deprel eq 'Oth')
        {
            ###!!! AuxZ Coord
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

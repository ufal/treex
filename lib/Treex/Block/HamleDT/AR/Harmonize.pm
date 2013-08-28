package Treex::Block::HamleDT::AR::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Arabic tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone, 'padt');
    $self->attach_final_punctuation_to_root($root);
    $self->fill_in_lemmas($root);
    $self->fix_coap_ismember($root);
    $self->restructure_coordination($root);
    $self->fix_auxp($root);
}

#------------------------------------------------------------------------------
# Adjusts analytical functions (syntactic tags). This method is called
# deprel_to_afun() due to compatibility reasons. Nevertheless, it does not use
# the value of the conll/deprel attribute. We converted the PADT PML files
# directly to Treex without CoNLL, so the afun attribute already has a value.
# We filled conll/deprel as well but the values are not identical to afun: they
# also reflect other attributes such as is_member.
# less /net/data/conll/2007/ar/doc/README
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun   = $node->afun();

        # PADT defines some afuns that were not defined in PDT.
        # PredE = existential predicate
        # PredC = conjunction as the clause's head
        # PredP = preposition as the clause's head
        if ( $afun =~ m/^Pred[ECP]$/ )
        {
            #$afun = 'Pred';
        }

        # Ante = anteposition
        elsif ( $afun eq 'Ante' )
        {
            #$afun = 'Apos';
        }

        # AuxE = emphasizing expression
        # AuxM = modifying expression
        elsif ( $afun =~ m/^Aux[EM]$/ )
        {
            #$afun = 'AuxZ';
        }

        # _ = excessive token esp. due to a typo
        elsif ( $afun eq '_' )
        {
            $afun = '';
        }

        # Beware: PADT allows joint afuns such as 'ExD|Sb', which are not allowed by the PML schema.
        $afun =~ s/\|.*//;
        $node->set_afun($afun || 'NR');
    }
}

#------------------------------------------------------------------------------
# Repairs annotation of coordinations and appositions. The current PADT data
# contain nodes that are marked as members of either coordination or apposition
# but their parent's afun is neither Coord nor Apos. It also contains nodes
# with one of these afuns that do not have any children marked as members.
#------------------------------------------------------------------------------
sub fix_coap_ismember
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Orphan conjuncts.
        if($node->is_member())
        {
            my $parent = $node->parent();
            if($parent->afun() !~ m/^(Coord|Apos)$/)
            {
                # Make the parent Coord root if it is a coordinating conjunction or a comma.
                if($parent->get_iset('pos') eq 'conj' || $parent->form() eq '،')
                {
                    $parent->set_afun('Coord');
                }
                # Otherwise remove the membership flag.
                else
                {
                    $node->set_is_member(0);
                }
            }
        }
        # Empty coordinations.
        if($node->afun() =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} ($node->children()))
        {
            my $afun = $node->afun();
            my @children = $node->children();
            # Misannotated deficient coordination (a single conjunct).
            if($afun eq 'Coord' && scalar(@children)==1)
            {
                $children[0]->set_is_member(1);
            }
            # Misannotated normal coordination.
            # Most such Coord nodes are conjunctions ($node->get_iset('pos') eq 'conj')
            # but some of them are punctuations and quite a few are unrecognized words
            # that should have been split into multiple tokens, the first token being the
            # conjunction و wa (and).
            elsif($afun eq 'Coord' && scalar(@children)>1)
            {
                # Exclude AuxG children, e.g. quotation marks around the coordination, or commas between conjuncts.
                # Exclude AuxY children, i.e. additional conjunctions.
                my $found = 0;
                foreach my $child (@children)
                {
                    unless($child->afun() =~ m/^(AuxG|AuxY)$/)
                    {
                        $child->set_is_member(1);
                        $found = 1;
                    }
                }
                # What to do if there were only ineligible children?
                unless($found)
                {
                    ###!!!
                }
            }
            # Misannotated apposition.
            elsif($afun eq 'Apos' && scalar(@children)==2)
            {
                $children[0]->set_is_member(1);
                $children[1]->set_is_member(1);
            }
            # There was one occurrence of the following error.
            elsif($afun eq 'Apos' && $node->get_iset('pos') eq 'conj' && scalar(@children)>2)
            {
                $node->set_afun('Coord');
                foreach my $child (@children)
                {
                    $child->set_is_member(1);
                }
            }
            # Apposition with one child? I do not understand the examples but I assume that these are actually members of appositions that lack the joining node.
            # ###!!! This may be quite wrong! Get translations of the examples!
            elsif($afun eq 'Apos' && scalar(@children)==1)
            {
                $node->set_afun('Apposition');
            }
            # Other errors: coordination/apposition root has no children at all.
            elsif(scalar(@children)==0)
            {
                # We cannot say how this error arose.
                # Resort to default tags: ExD under the root, Adv under a verb, Atr elsewhere.
                $self->set_default_afun($node);
            }
            ###!!! Další případy: uzel se spojkou wa má Apos (ne Coord!), má tři děti - předměty slovesa, které je jeho rodičem.
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in PADT. Even though
# the harmonized shape will be almost identical (both are Prague styles), there
# are slight deviations that we want to polish by decoding and re-encoding the
# coordinations. For example, in PADT the first conjunction serves as the head
# of multi-conjunct coordination, while HamleDT uses the last conjunction.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_prague($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_conjuncts();
    push(@recurse, $coordination->get_shared_modifiers());
    return @recurse;
}

#------------------------------------------------------------------------------
# Reconsiders syntactic tags of prepositions. Most of them should have AuxP and
# those that don't should have a good reason.
#------------------------------------------------------------------------------
sub fix_auxp
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->get_iset('pos') eq 'prep' && scalar($node->children())>=1)
        {
            # There is no reason for prepositions to receive AuxY.
            # AuxY is meant for "other adverbs and particles, i.e. those that cannot be included elsewhere".
            # AuxM is meant for particles that modify the meaning of verbs.
            # Some of them are tagged and behave like prepositions and I don't see why we couldn't give them AuxP.
            # Example: nahwa išrína áman (about twenty years)
            # Example 2: siwá li 13600 sarínin (except for 13600 beds)
            # AuxE marks "emphatic particles". It is occasionally observed at prepositions. It is probably an annotation error.
            # Occasionally we see prepositions tagged by other afuns (Atr, Obj, Adv). I asked Ota Smrž to look at the examples
            # but my current hypothesis is that these are annotation errors.
            if($node->afun() =~ m/^(AuxY|AuxM|AuxE|Atr|Obj|Adv)$/)
            {
                $node->set_afun('AuxP');
            }
        }
        # Compound prepositions. Example:
        # "bihasabi" (according to) is split during second tokenization into
        # "bi" (by, with) and "hasabi" (according to; "hasb" is a noun meaning "reckoning", "calculation")
        # Original annotation: Both "hasabi" and the noun are attached to "bi". "hasabi" gets "AuxY".
        # In PDT, compound prepositions ("na rozdíl od") are annotated similarly but "hasabi" would get "AuxP" (despite being a leave).
        # In HamleDT, we prefer to put the tokens of the compound preposition in a chain ("hasabi" on "bi", noun on "hasabi").
        # Example 2:
        # "bi-al-qurbi" (with nearness) "min" (from) "qaryati" (village) = near the village
        # Original annotation: "min" is the head. "bi", "al-qurbi" and "qaryati" are attached to it (AuxY/RR, AuxY/NN, AtrAdv/NN).
        if($node->get_iset('pos') eq 'prep' && $node->afun() eq 'AuxY' && scalar($node->children())==0)
        {
            my $parent = $node->parent();
            if($parent)
            {
                my @children = $parent->children();
                # bihasabi
                if($parent->get_iset('pos') eq 'prep' && $parent->afun() eq 'AuxP' && scalar(@children)==2 && $node->ord()>$parent->ord())
                {
                    foreach my $child (@children)
                    {
                        if($child!=$node)
                        {
                            $child->set_parent($node);
                        }
                    }
                    $node->set_afun('AuxP');
                }
                # min chilála (during)
                elsif($parent->get_iset('pos') eq 'prep' && $parent->afun() eq 'AuxP' && scalar(@children)==2 && $node->ord()<$parent->ord())
                {
                    $node->set_parent($parent->parent());
                    $node->set_afun('AuxP');
                    $parent->set_parent($node);
                    if($parent->is_member())
                    {
                        $node->set_is_member(1);
                        $parent->set_is_member(0);
                    }
                }
                # bilqurbi min
                elsif($parent->get_iset('pos') eq 'prep' && $parent->afun() eq 'AuxP' && scalar(@children)==3 && $children[1]->afun() eq 'AuxY' && $parent->ord()==$node->ord()+2 && $children[2]->ord()==$parent->ord()+1)
                {
                    $children[1]->set_parent($node);
                    $children[1]->set_afun('AuxP');
                    $node->set_parent($parent->parent());
                    $node->set_afun('AuxP');
                    $parent->set_parent($node);
                    if($parent->is_member())
                    {
                        $node->set_is_member(1);
                        $parent->set_is_member(0);
                    }
                }
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::AR::Harmonize

Converts PADT (Prague Arabic Dependency Treebank) trees to the style of HamleDT.
The structure of the trees should already adhere to the guidelines because the
the annotation scheme of PADT is very similar to PDT. Some
minor adjustments to the analytical functions may be needed.
Morphological tags will be decoded into Interset and to the 15-character positional tags
of PDT. (Note that Arabic positional tagset in PADT differs from the Czech
tagset of PDT.)

=back

=cut

# Copyright 2011, 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

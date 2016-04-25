package Treex::Block::HamleDT::AR::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ar::padt',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Arabic tree, converts morphosyntactic tags to the PDT tagset,
# converts dependency relations, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->fill_in_lemmas($root);
    $self->fix_coap_ismember($root);
    $self->fix_auxp($root);
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
# Copies to wild/misc attributes that we want to preserve in the CoNLL-U file.
# Perhaps this task would be better match for Prague-to-UD conversion but it is
# specific for PADT and Udep.pm is used for all treebanks.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    # Detect sequences of nodes that share their source surface token.
    my @fused_indices;
    for(my $i = 0; $i < $#nodes; $i++)
    {
        my $wrf0 = $nodes[$i]->wild()->{wrf} // '';
        my $wrf1 = $nodes[$i+1]->wild()->{wrf} // '';
        log_warn('Missing reference to surface token') if($wrf0 eq '' || $wrf1 eq '');
        if($wrf1 eq $wrf0)
        {
            push(@fused_indices, $i) if(scalar(@fused_indices)==0);
            push(@fused_indices, $i+1);
        }
        else
        {
            if(scalar(@fused_indices)>1)
            {
                # We currently set the following wild attributes for fused nodes (see Write::CoNLLU):
                # fused = start|middle|end
                # fused_end = ord of the last node
                # fused_form
                for(my $j = 0; $j <= $#fused_indices; $j++)
                {
                    my $wild = $nodes[$fused_indices[$j]]->wild();
                    $wild->{fused} = ($j==0) ? 'start' : ($j==$#fused_indices) ? 'end' : 'middle';
                    $wild->{fused_end} = $nodes[$fused_indices[-1]]->ord();
                    $wild->{fused_form} = $wild->{aform};
                    # We will make the unvocalized surface forms the main forms of all nodes, except for syntactic words that are fused on surface.
                    $wild->{aform} = $nodes[$fused_indices[$j]]->form();
                }
            }
            splice(@fused_indices);
        }
    }
    # Copy attributes that shall be preserved to MISC.
    foreach my $node (@nodes)
    {
        my $wild = $node->wild();
        my @misc;
        if(defined($wild->{misc}))
        {
            @misc = split(/\|/, $wild->{misc});
        }
        # Aform is the original unvocalized surface form. It should appear as FORM in the CoNLL-U file. Except for parts of fused forms where only vocalized form is available.
        # Vform is the vocalized lexical form assigned during morphological analysis. It is a MISC attribute. But for unknown words the attribute contains only a copy of the surface form.
        @misc = $self->add_misc('Vform', $node->form());
        if(defined($wild->{aform}))
        {
            $node->set_form($wild->{aform});
        }
        if(defined($wild->{gloss}))
        {
            @misc = $self->add_misc('Gloss', $wild->{gloss}, @misc);
        }
        if(defined($wild->{root}))
        {
            @misc = $self->add_misc('Root', $wild->{root}, @misc);
        }
        if(scalar(@misc)>0)
        {
            $wild->{misc} = join('|', @misc);
        }
    }
}



#------------------------------------------------------------------------------
# Adds an attribute-value pair to the list of MISC attributes for the last
# column of the CoNLL-U file.
#------------------------------------------------------------------------------
sub add_misc
{
    my $self = shift;
    my $misc_name = shift;
    my $misc_value = shift;
    my @misc = @_;
    # Escape special characters & and | (only in the value; we assume that the name is safe).
    $misc_value =~ s/&/&amp;/g;
    $misc_value =~ s/\|/&verbar;/g;
    # We assume that all MISC attributes are unique. Erase previous value if any.
    @misc = grep {!m/^$misc_name=/} (@misc);
    push(@misc, "$misc_name=$misc_value");
    return @misc;
}



#------------------------------------------------------------------------------
# Adjusts dependency relation labels.
# less /net/data/conll/2007/ar/doc/README
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

        # PADT defines some deprels that were not defined in PDT.
        # PredE = existential predicate
        # PredC = conjunction as the clause's head
        if ( $deprel =~ m/^Pred[EC]$/ )
        {
            $deprel = 'Pred';
        }

        # PredP = preposition as the clause's head
        # (It is a prepositional phrase in the position of a nominal predicate. In other languages there would be a copula but Arabic does not use overt copulas.)
        elsif ( $deprel eq 'PredP' )
        {
            $deprel = 'AuxP';
        }

        # Ante = anteposition
        elsif ( $deprel eq 'Ante' )
        {
            $deprel = 'Apposition';
        }

        # AuxE = emphasizing expression
        elsif ( $deprel eq 'AuxE' )
        {
            $deprel = 'AuxZ';
        }

        # AuxM = modifying expression
        elsif ( $deprel eq 'AuxM' )
        {
            # Some instances are prepositional phrases. The AuxM label appears at the preposition instead of AuxP.
            # Similarly to prepositions the real deprel of the whole phrase is at the child of the preposition: Sb, Obj, Pnom etc.
            if ( $node->is_adposition() )
            {
                $deprel = 'AuxP';
            }
            # AuxM is also used with negative particles لَا (lā), لَم (lam) and لَن (lan).
            elsif ( $node->is_particle() && $node->form() =~ m/^لَ?[امن]/ )
            {
                $deprel = 'Neg';
            }
            # AuxM is also used with future particles سَ (sa) and سَوفَ (sawfa).
            elsif ( $node->is_particle() && $node->form() =~ m/^سَ?(وفَ?)$/ )
            {
                $deprel = 'AuxV';
            }
            ###!!! TODO: Explore the rest!
            # Some of them will also act as Neg or AuxV, e.g. لَيسَ (laysa) is negation but it is also a verb ("be not").
            # See also https://en.wiktionary.org/wiki/%D9%84%D9%8A%D8%B3
            # Note that "laysa" is usually analyzed as copula and there is a Pnom child. But in a handful of cases
            # it is attached to a following preposition as AuxM. Here I believe that "laysa" should still be copula
            # and the prepositional phrase should be the nominal predicate.
            elsif ( $node->form() eq 'لَيسَ' )
            {
                # The structure will be transformed later.
                $deprel = 'Cop';
            }
            else
            {
                $deprel = 'AuxV';
            }
        }

        # _ = excessive token esp. due to a typo
        elsif ( $deprel eq '_' )
        {
            $deprel = '';
        }

        # combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        elsif ( $deprel =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $deprel = 'Atr';
        }

        # Beware: PADT allows joint deprels such as 'ExD|Sb', which are not allowed by the PML schema.
        $deprel =~ s/\|.*//;
        $node->set_deprel($deprel || 'NR');
    }
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Should be called
# from convert_deprels() so that it precedes any tree operations that the
# superordinate class may want to do.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # wa/conj/AuxY anna/conj/AuxC hu/pron/AuxY ./punc/AuxK
    # AuxY(anna, hu); all the others are attached directly to the root.
    # The correct Prague-style annotation would be:
    # "hu" must be ExD. It is effectively the root word because its AuxC parent is ignored, and it is not a verb.
    # "wa" is either attached as AuxY to "hu", or (more like the Czech trees) it is the root word marked Coord, and "anna" is attached to it as AuxC and is_member.
    if(scalar(@nodes) == 4 &&
       $nodes[0]->is_conjunction() && $nodes[1]->is_conjunction() && $nodes[2]->is_pronoun() && $nodes[3]->is_punctuation() &&
       $nodes[0]->parent()->is_root() && $nodes[1]->parent()->is_root() && $nodes[2]->parent() == $nodes[1] && $nodes[3]->parent()->is_root() &&
       $nodes[0]->deprel() eq 'AuxY' && $nodes[1]->deprel() eq 'AuxC' && $nodes[3]->deprel() eq 'AuxK')
    {
        $nodes[0]->set_deprel('Coord');
        $nodes[1]->set_parent($nodes[0]);
        $nodes[2]->set_deprel('ExD');
    }
    # This must also be solved before the parent block applies any of its transformations.
    # If the landscape is changed, we will no longer recognize the context for laysa.
    $self->fix_laysa($root);
    # Fix coordination without conjuncts.
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^(Coord|Apos)(_|$)/ && !grep {$_->is_member()} ($node->children()))
        {
            my @children = $node->children();
            if(scalar(@children)==0)
            {
                $node->set_deprel('AuxY');
            }
            else
            {
                $self->identify_coap_members($node);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Arabic  لَيسَ (laysa) is a negative copula ("be not"). In many cases it is
# attached as copula and it has a child attached as Pnom. In a few cases where
# the nominal predicate was expressed as a prepositional phrase, the copula was
# attached as AuxM to the preposition. We have temporarily changed the label to
# Cop. This method will make the dependency structure parallel to other nominal
# predicates.
#------------------------------------------------------------------------------
sub fix_laysa
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $deprel = $node->deprel();
        if($deprel eq 'Cop')
        {
            # We have not assigned the Cop label to any other node than "laysa".
            # But other tree transformations may have caused that the label ended up elsewhere.
            # We cannot keep it so we will replace it by AuxV, which the verb would get otherwise.
            ###!!! TODO: This should be investigated further! This solution is probably incorrect!
            $node->set_deprel('AuxV');
            if($form eq 'لَيسَ')
            {
                my $laysa = $node;
                # In all cases that I have seen the parent was a preposition. Sometimes it was a coordination member at the same time.
                # However, there may be other cases that I have not seen because they did not violate the particular test that I used.
                my $preposition = $node->parent();
                if($preposition->is_adposition())
                {
                    my $parent = $preposition->parent();
                    $laysa->set_parent($parent);
                    if($preposition->is_member())
                    {
                        $laysa->set_is_member(1);
                        $preposition->set_is_member(0);
                    }
                    $preposition->set_parent($laysa);
                    # Sometimes the preposition has more than one child besides laysa. The non-argument children are AuxY or AuxE (AuxE would now be replaced by AuxZ).
                    my @children = $preposition->children();
                    my @arguments = grep {$_->deprel() !~ m/^Aux[EYZ]$/} (@children);
                    unless(scalar(@arguments) == 1)
                    {
                        log_warn("No or too many arguments");
                        next;
                    }
                    my $argument = $arguments[0];
                    # Only the argument must be attached to the preposition. All other children must be attached to the argument.
                    foreach my $child (@children)
                    {
                        unless($child == $argument)
                        {
                            $child->set_parent($argument);
                        }
                    }
                    # Swap dependency relations.
                    $deprel = $argument->deprel();
                    $laysa->set_deprel($deprel) unless($deprel eq 'Cop');
                    $argument->set_deprel('Pnom');
                }
                else
                {
                    log_warn("Expected preposition");
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Repairs annotation of coordinations and appositions. The current PADT data
# contain nodes that are marked as members of either coordination or apposition
# but their parent's deprel is neither Coord nor Apos. It also contains nodes
# with one of these deprels that do not have any children marked as members.
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
            if($parent->deprel() !~ m/^(Coord|Apos)$/)
            {
                # Make the parent Coord root if it is a coordinating conjunction or a comma.
                if($parent->get_iset('pos') eq 'conj' || $parent->form() && $parent->form() eq '،')
                {
                    $parent->set_deprel('Coord');
                }
                # Otherwise remove the membership flag.
                else
                {
                    $node->set_is_member(0);
                }
            }
        }
        # Empty coordinations.
        if($node->deprel() =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} ($node->children()))
        {
            my $deprel = $node->deprel();
            my @children = $node->children();
            # Misannotated deficient coordination (a single conjunct).
            if($deprel eq 'Coord' && scalar(@children)==1)
            {
                $children[0]->set_is_member(1);
            }
            # Misannotated normal coordination.
            # Most such Coord nodes are conjunctions ($node->get_iset('pos') eq 'conj')
            # but some of them are punctuations and quite a few are unrecognized words
            # that should have been split into multiple tokens, the first token being the
            # conjunction و wa (and).
            elsif($deprel eq 'Coord' && scalar(@children)>1)
            {
                # Exclude AuxG children, e.g. quotation marks around the coordination, or commas between conjuncts.
                # Exclude AuxY children, i.e. additional conjunctions.
                my $found = 0;
                foreach my $child (@children)
                {
                    unless($child->deprel() =~ m/^(AuxG|AuxY)$/)
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
            elsif($deprel eq 'Apos' && scalar(@children)==2)
            {
                $children[0]->set_is_member(1);
                $children[1]->set_is_member(1);
            }
            # There was one occurrence of the following error.
            elsif($deprel eq 'Apos' && $node->get_iset('pos') eq 'conj' && scalar(@children)>2)
            {
                $node->set_deprel('Coord');
                foreach my $child (@children)
                {
                    $child->set_is_member(1);
                }
            }
            # Apposition with one child? I do not understand the examples but I assume that these are actually members of appositions that lack the joining node.
            # ###!!! This may be quite wrong! Get translations of the examples!
            elsif($deprel eq 'Apos' && scalar(@children)==1)
            {
                $node->set_deprel('Apposition');
            }
            # Other errors: coordination/apposition root has no children at all.
            elsif(scalar(@children)==0)
            {
                # We cannot say how this error arose.
                # Resort to default tags: ExD under the root, Adv under a verb, Atr elsewhere.
                $self->set_default_deprel($node);
            }
            ###!!! Další případy: uzel se spojkou wa má Apos (ne Coord!), má tři děti - předměty slovesa, které je jeho rodičem.
        }
    }
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
        if($node->is_adposition() && scalar($node->children())>=1)
        {
            # There is no reason for prepositions to receive AuxY.
            # AuxY is meant for "other adverbs and particles, i.e. those that cannot be included elsewhere".
            # AuxM is meant for particles that modify the meaning of verbs.
            # Some of them are tagged and behave like prepositions and I don't see why we couldn't give them AuxP.
            # Example: nahwa išrína áman (about twenty years)
            # Example 2: siwá li 13600 sarínin (except for 13600 beds)
            # AuxE marks "emphatic particles". It is occasionally observed at prepositions. It is probably an annotation error.
            # Occasionally we see prepositions tagged by other deprels (Atr, Obj, Adv). I asked Ota Smrž to look at the examples
            # but my current hypothesis is that these are annotation errors.
            if($node->deprel() =~ m/^(AuxY|AuxM|AuxE|Atr|Obj|Adv)$/)
            {
                $node->set_deprel('AuxP');
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
        if($node->is_adposition() && $node->deprel() eq 'AuxY' && scalar($node->children())==0)
        {
            my $parent = $node->parent();
            if($parent)
            {
                my @children = $parent->children();
                # bihasabi
                if($parent->is_adposition() && $parent->deprel() eq 'AuxP' && scalar(@children)==2 && $node->ord()>$parent->ord())
                {
                    foreach my $child (@children)
                    {
                        if($child!=$node)
                        {
                            $child->set_parent($node);
                        }
                    }
                    $node->set_deprel('AuxP');
                }
                # min chilála (during)
                elsif($parent->is_adposition() && $parent->deprel() eq 'AuxP' && scalar(@children)==2 && $node->ord()<$parent->ord())
                {
                    $node->set_parent($parent->parent());
                    $node->set_deprel('AuxP');
                    $parent->set_parent($node);
                    if($parent->is_member())
                    {
                        $node->set_is_member(1);
                        $parent->set_is_member(0);
                    }
                }
                # bilqurbi min
                elsif($parent->is_adposition() && $parent->deprel() eq 'AuxP' && scalar(@children)==3 && $children[1]->deprel() eq 'AuxY' && $parent->ord()==$node->ord()+2 && $children[2]->ord()==$parent->ord()+1)
                {
                    $children[1]->set_parent($node);
                    $children[1]->set_deprel('AuxP');
                    $node->set_parent($parent->parent());
                    $node->set_deprel('AuxP');
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

# Copyright 2011, 2013, 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

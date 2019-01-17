package Treex::Block::HamleDT::LT::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'lt::multext',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Lithuanian tree and transforms it to adhere to the HamleDT
# guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    return;
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
    # Some nodes have no tags and the Interset driver is not happy about it.
    # Typically these are punctuation nodes. Multext-East does not define
    # a common tag for punctuation but some Multext-based tagsets use "Z",
    # and that is what Interset eventually expects.
    my $tag = $node->tag();
    if(!defined($tag) || $tag eq '')
    {
        $tag = 'Z';
    }
    return $tag;
}



#------------------------------------------------------------------------------
# Adds Interset features that cannot be decoded from the PDT tags but they can
# be inferred from lemmas and word forms. This method is called from
# SUPER->process_zone().
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form() // '';
        # Several times, a quotation mark is XPOS-tagged "Aux", which should
        # have been its afun (deprel), and the afun is "-". By the time this
        # method is called, $node->tag() has been copied as original tag to
        # $node->conll_pos(), so we must update it there too.
        my $origtag = $node->conll_pos() // '';
        if($form =~ m/^\pP+$/ && $origtag eq 'Aux')
        {
            $origtag = 'Z';
            $node->set_conll_pos($origtag);
            $node->set_tag('Z');
            # Decode it to Interset again.
            $self->decode_iset($node);
            # The corresponding PDT-like tag will be created after this method
            # finished, so we do not have to care of it now.
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
    # First loop: copy deprel to deprel and convert _CO and _AP to is_member.
    # Leave everything else untouched until we know that is_member is set correctly for all nodes.
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        # There were erroneous afuns with trailing spaces in Alksnis!
        $deprel =~ s/\s+$//;
        $deprel =~ s/^\s+//;
        $deprel =~ s/^aux([a-z])$/Aux\U$1/i;
        # The _Co suffix signals conjuncts.
        # The _Ap suffix signals members of apposition.
        # We will later reshape appositions but the routine will expect is_member set.
        if($deprel =~ s/_(Co|Ap)$//i || $deprel =~ s/_Co_/_/i)
        {
            $node->set_is_member(1);
        }
        # Annotation errors: Coord must not be leaf.
        if($deprel eq 'Coord' && $node->is_leaf())
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            elsif($node->is_punctuation())
            {
                $deprel = 'AuxG';
            }
            else
            {
                $deprel = 'ExD';
            }
        }
        $node->set_deprel($deprel);
    }
    # Second loop: process chained dependency labels and decide, what nodes are ExD, Coord, Apos, AuxP or AuxC.
    # At the same time translate the other deprels to the dialect of HamleDT.
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        my $parent = $node->parent();
        # There are chained dependency labels that describe situation around elipsis.
        # They ought to contain an ExD, which may be indexed (e.g. ExD0).
        # The tag before ExD describes the dependency of the node on its elided parent.
        # The tag after ExD describes the dependency of the elided parent on the grandparent.
        # Example: ADV_ExD0_PRED_CO
        # Similar cases in PDT get just ExD.
        if($deprel =~ m/ExD/i)
        {
            # If the chained label is something like COORD_ExD0_OBJ_CO_ExD1_PRED,
            # this node should be Coord and the conjuncts should get ExD.
            # However, we still cannot set deprel=ExD for the conjuncts.
            # This would involve traversing also AuxP nodes and nested Coord, so we need to have all Coords in place first.
            if($deprel =~ m/^Coord/i)
            {
                $node->set_deprel('Coord');
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            elsif($deprel =~ m/^Apos/i)
            {
                $node->set_deprel('Apos');
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            # Do not change AuxX and AuxG either.
            # These deprels reflect more what the node is than how it modifies its parent.
            elsif($deprel =~ m/^(Aux[CPGX])/)
            {
                $node->set_deprel($1);
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            else
            {
                $node->set_deprel('ExD');
            }
        }
        # Deprel may have changed in the previous if, let's update $deprel.
        $deprel = $node->deprel();
        if($deprel =~ s/_Par$//i)
        {
            ###!!! Už na to nemám nervy. Parenteze se v PDT moc často nevyskytovala,
            ###!!! takže její převod a interakce s koordinací a dalšími konstrukcemi
            ###!!! asi není dotažená a občas mi to nějak hapruje.
            ###!!! Jeden PredN_Par napojený jako shared modifier na Coord spojku
            ###!!! se mi tam rozsypal a nepřevedl, tak ho prostě násilím předělám
            ###!!! na obyčejný Pred.
            if($deprel eq 'PredN')
            {
                $deprel = 'Pred';
            }
            else
            {
                $node->set_is_parenthesis_root(1);
            }
        }
        if($deprel =~ m/^PredV_(Sub|Obj|Adj|Atr)$/i)
        {
            $deprel = $1;
        }
        # Sub is subject; in PDT it is labeled "Sb".
        # One subject in Alksnis is by error labeled "Suj".
        if($deprel =~ m/^Su[bj]$/i)
        {
            $deprel = 'Sb';
        }
        # PredN seems to be the nominal predicate. If the copula "būti" is present,
        # the topology is similar to that of Pnom in Czech. But in Lithuanian,
        # the copula seems to be omitted often. If the copula is missing, the
        # nominal predicate (PredN) is attached to the subject, which is the
        # opposite of what we want in UD. Since we are now doing just Prague
        # harmonization (and there is no similar construction in Czech, we just
        # leave PredN there for further processing).
        if($deprel eq 'PredN')
        {
            my $plemma = $parent->lemma();
            if(defined($plemma) && $plemma eq 'būti')
            {
                $deprel = 'Pnom';
            }
        }
        # PredV seems to be often an infinitive completing another verb.
        if($deprel =~ m/^PredV$/i)
        {
            $deprel = 'Obj';
        }
        # AuxL is the first name attached to the last name.
        if($deprel =~ m/^AuxL$/i)
        {
            $deprel = 'Atr';
        }
        if($deprel =~ m/^Aux$/i)
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            elsif($node->is_punctuation())
            {
                $deprel = 'AuxG';
            }
            else
            {
                $deprel = 'AuxZ';
            }
        }
        # Rgp is an error (it is the POS tag for adverbs, not an afun).
        if($deprel =~ m/^Rgp$/i)
        {
            $deprel = 'Adv';
        }
        # Adj is Lithuanian-specific and it probably means "adjunct".
        if($deprel eq 'Adj')
        {
            if($parent->is_noun() || $parent->is_numeral())
            {
                $deprel = 'Atr';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # Pred_Sub is a clause that modifies a coreferential pronoun, which
        # serves as a subject of the matrix clause. Example:
        # tai, ką mes kalbame = what we are talking about (lit. "that, what we discuss")
        # Similarly, Pred_Obj seems to be a clause that modifies a noun.
        if($deprel =~ m/^PredN?_(Sub|Obj|Adj|Atr)$/i)
        {
            $deprel = 'Atr';
        }
        # Combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if($deprel =~ m/^((Atr)|(Adv)|(Obj))_?((Atr)|(Adv)|(Obj))/i)
        {
            $deprel = 'Atr';
        }
        # AuxG cannot be conjunct in HamleDT but it happens in AGDT (and we cannot be sure that it does not happen in Alksnis).
        if($node->deprel() eq 'AuxG' && $node->is_member())
        {
            $node->set_is_member(undef);
        }
        # Several times, a quotation mark is XPOS-tagged "Aux", which should have been its afun (deprel),
        # and the afun is "-". We have already fixed the XPOS tag in fix_morphology() because
        # that method is called before converting the tags, unlike this one. But now we also must
        # fix the dependency relation.
        # There are also a few non-punctuation nodes that lack the afun.
        if($deprel eq '-')
        {
            if($node->is_punctuation())
            {
                $deprel = 'AuxG';
            }
            elsif($node->is_conjunction())
            {
                $deprel = 'AuxY';
            }
            else
            {
                $deprel = 'ExD';
            }
        }
        # Parenthetical.
        if($deprel =~ m/^par$/i)
        {
            $node->set_is_parenthesis_root(1);
            $deprel = 'Pred';
        }
        $node->set_deprel($deprel);
    }
    # Third loop: we still cannot rely on is_member because it is not guaranteed that it is always set directly under COORD or APOS.
    # The source data follow the PDT convention that AuxP and AuxC nodes do not have it (and thus it is marked at a lower level).
    # In contrast, Treex marks is_member directly under Coord or Apos. We cannot convert it later because we need reliable is_member
    # for deprel conversion.
    foreach my $node (@nodes)
    {
        # no is_member allowed directly below root
        if($node->is_member() and $node->parent()->is_root())
        {
            $node->set_is_member(undef);
        }
        if($node->is_member())
        {
            my $new_member = $self->_climb_up_below_coap($node);
            if($new_member && $new_member != $node)
            {
                $new_member->set_is_member(1);
                $node->set_is_member(undef);
            }
        }
    }
    # Fourth loop: if there are inconsistencies in coordination even after moving is_member up to Aux[PC], fix them.
    foreach my $node (@nodes)
    {
        if($node->deprel() !~ m/^(Coord|Apos)$/)
        {
            # If a conjunction or punctuation node has children with is_member set, it must be labeled as Coord or Apos.
            my @children = $node->get_children({'ordered' => 1});
            my @members = grep {$_->is_member()} (@children);
            if(scalar(@members)>0)
            {
                if($node->iset()->pos() =~ m/^(conj|punc|part|adv)$/)
                {
                    $node->set_deprel('Coord');
                }
                else
                {
                    foreach my $member (@members)
                    {
                        $member->set_is_member(undef);
                    }
                }
            }
            # Punctuation can have children only if it heads coordination or apposition.
            # By default we assume apposition, provided the configuration seems compatible with apposition.
            elsif($node->is_punctuation())
            {
                # Before we decide that it is apposition or coordination, let's get rid of children that are themselves punctuation.
                my @punctchildren = grep {$_->is_punctuation()} (@children);
                my @nopunctchildren = grep {!$_->is_punctuation()} (@children);
                foreach my $child (@punctchildren)
                {
                    # For now, we simply attach the child higher. It is not safe
                    # w.r.t. nonprojectivities but there is no guarantee anyway
                    # that punctuation is projective, so we will have to look
                    # into that later.
                    my $newparent = $node->parent();
                    while($newparent->is_punctuation() && !$newparent->is_root())
                    {
                        $newparent = $newparent->parent();
                    }
                    $child->set_parent($newparent);
                    $child->set_is_member(undef);
                }
                if(scalar(@nopunctchildren)==2 &&
                    $nopunctchildren[0]->ord() < $node->ord() &&
                    $nopunctchildren[1]->ord() > $node->ord())
                {
                    $node->set_deprel('Apos');
                    $nopunctchildren[0]->set_is_member(1);
                    $nopunctchildren[1]->set_is_member(1);
                }
                elsif(scalar(@nopunctchildren)>=2)
                {
                    $node->set_deprel('Coord');
                    foreach my $child (@nopunctchildren)
                    {
                        $child->set_is_member(1);
                    }
                }
                elsif(scalar(@nopunctchildren)==1)
                {
                    # Attach the child as my sibling or even higher, if my parent is also punctuation.
                    my $newparent = $node->parent();
                    while($newparent->is_punctuation() && !$newparent->is_root())
                    {
                        $newparent = $newparent->parent();
                    }
                    $nopunctchildren[0]->set_parent($newparent);
                    $nopunctchildren[0]->set_is_member(undef);
                }
            }
        }
    }
    # Fifth loop: finish propagating ExD down the tree at coordination and apposition.
    foreach my $node (@nodes)
    {
        if($node->wild()->{'ExD conjuncts'})
        {
            # set_real_deprel() goes down if it sees Coord, Apos, AuxP or AuxC
            $self->set_real_deprel($node, 'ExD');
            delete($node->wild()->{'ExD conjuncts'});
        }
    }
}



#------------------------------------------------------------------------------
# Catches possible annotation inconsistencies.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        my $deprel = $node->deprel() // '';
        my $spanstring = $self->get_node_spanstring($node);
        if($form eq 'apie' && $deprel eq 'AuxK')
        {
            $node->set_deprel('AuxP');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::LT::Harmonize

Converts Alksnis (Lithuanian Treebank) trees to the style of HamleDT (Prague).
The two annotation styles are very similar, thus only minor changes take place.
Morphological tags are decoded into Interset.

=back

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::HamleDT::HI::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Hindi CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($a_root);
    $self->raise_postpositions($a_root);
    $self->raise_children_of_commas($a_root);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ltrc.iiit.ac.in/nlptools2010/files/documents/dep-tagset.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $pos    = $node->conll_pos();
        my $cpos   = $node->conll_cpos();

        #log_info("conllpos=".$pos.", isetpos=".$node->get_iset('pos'));

        # default assignment
        my $afun = $deprel;
        $afun = 'Atr';    # default assignment if nothing gets assigned

        if ( $deprel eq "main" ) {
            $afun = "Pred";
        }

        # Subject
        # r6-k1 ... documentation: karta of a conjunct verb (complex predicate)
        # Example from documentation: [r6-k1]
        # कल मंदिर का उदघाटन हुआ
        # kala manxira kA uxGAtana huA
        # kala maṁdira kā udaghāṭana huā
        # kal  mandir  ká udghátan   huá
        # yesterday temple of opening was
        # the temple was opened yesterday
        # r6-k1(manxira kA, uxGAtana)
        # The r6-k1 node is attached to the nominal part of the compound predicate. But it is the agent, and typically subject.
        if ( $deprel =~ /^(k1|pk1|k4a|r6-k1)$/ )
        {
            $afun = "Sb";
        }
        # ras-k1 ... associative karta. Not a subject. Someone secondary who assists the subject (asymmetric coordination).
        # Example: लश्कर के साथ = laśkara ke sātha = with Lashkar
        elsif($deprel eq 'ras-k1')
        {
            $afun = 'Adv';
        }
        # k1s ... vidheya karta (karta samanadhikarana) = noun complement of karta (according to documentation)
        # Training sentence 70:
        # फूकन भी पार्टी में अपनी उपेक्षा से आहत हैं ।
        # phūkana bhī pārṭī meṁ apanī upekṣā     se   āhata haiṁ .
        # Phukan  too party in  his   negligence with hurt  is   .
        # n       avy n     psp pn    n          psp  adj   v    punc
        # k1      lwg_rp k7 lwg_psp r6 adv       lwg_psp k1s main rsym
        # Phukan too was hurt at the party due to his negligence.
        elsif ( $deprel =~ m/^(k1s)$/ )
        {
            $afun = 'Pnom';
        }
        # k1u is not subject! One verb can have both k1 and k1u but it cannot have two subjects.
        # k1u is missing from the documentation so I do not know what exactly it means.
        # Training sentence 238:
        # कई मामलों में उनकी राय राजनीतिक सत्ता की राय से अलग भी होती थी ।
        # kaī māmaloṁ meṁ unakī rāya    rājanītika sattā kī rāya    se alaga     bhī hotī thī .
        # many cases  in  their opinion political  power of opinion to different too been was .
        # avy n       psp pn    n       adj        n     psp n      psp adj      avy v    v   punc
        # nmod_adj k7 lwg_psp r6 k1     nmod_adj   r6    lwg_psp k1u lwg_psp pof lwg_rp main lwg_vaux rsym
        # In many cases their opinion was different from the opinion of the political power.
        elsif ( $deprel =~ m/^(k1u)$/ )
        {
            $afun = 'Atv'; # or Pnom?
        }
        elsif ( $deprel =~ /^(jk1|mk1)$/ ) {
            $afun = "Obj";
        }
        elsif ( $deprel eq "k1s" ) {
            $afun = "Atv";    # noun complements
        }
        # r6-k2 is analogical to r6-k1, see above.
        elsif ( $deprel =~ /^(k2|k2p|k2g|k2s|k2u|r6-k2|ras-k2)$/ ) {
            $afun = "Obj";
        }
        elsif ( $deprel eq "k3" ) {
            $afun = "Adv";    # Instrumental
        }
        elsif ( $deprel eq "k4" || $deprel eq "k4s" ) {
            $afun = "Obj";    # recipient of the action
        }
        elsif ( $deprel eq "k5" ) {
            $afun = "Adv";    # source of an activity
        }
        elsif ( $deprel =~ /^(k5prk|k7t|k7p|k7|k7u|vmod)$/ ) {
            $afun = "Adv";    # reason, location
        }
        elsif ( $deprel =~ /^(r6|r6v)$/ ) {
            $afun = "Atr";    # genitive
        }
        elsif ( $deprel =~ /^(adv|sent-adv|rd|rh|rt|ras-NEG|rsp|NEG)$/ ) {
            $afun = "Adv";
        }
        elsif ( $deprel eq "rs" ) {
            $afun = "Atr";    # noun elaboration ... not sure
        }
        elsif ( $deprel eq "rad" ) {
            $afun = "Atr";    # address ... not sure
        }
        elsif ( $deprel eq "nmod__relc" || $deprel eq "nmod__adj" ) {
            $afun = "Atr";    # relative clause modifying noun
        }
        elsif ( $deprel eq "rbmod" || $deprel eq "rbmod__relc" ) {
            $afun = "Adv";    # relative clause modifying adverb
        }
        elsif ( $deprel eq "jjmod__relc" ) {
            $afun = "Atr";    # relative clause modifying adjective
        }
        elsif ( $deprel eq "nmod" ) {
            $afun = "Atr";    # attributes
        }
        elsif ( $deprel eq "jjmod" ) {
            $afun = "Atr";    # modifiers of adjectives.
        }
        # "pof" means "part of relation" (according to documentation).
        # It is often found at the content part of "compound verbs" (light verb plus noun or adjective, the noun/adjective is pof).
        # Training sentence 236:
        # निर्वाह किया
        # nirvāha kiyā = performed
        # nirvāha = sustenance (cs:obživa)
        # kiyā = masculine singular perfect participle of karanā
        # = light verb (to do)
        elsif ( $deprel eq 'pof' )
        {
            # It would be useful to have a special tag for nominal parts of compound verbs.
            # We do not have it now.
            $afun = 'Obj';
        }
        elsif ( $deprel eq "ccof" ) {
            ###!!! The original treebank does not distinguish between subordinating conjunctions used as complementizers
            ###!!! (such as 'ki' = 'that') and coordinating conjunctions (such as 'aur' = 'and').
            ###!!! Ideally, we would identify all subordinating cases and handle them properly.
            ###!!! Currently we only identify the most frequent case and get away with the adverbial meaning of the relative clause.
            if($node->parent()->get_iset('subpos') eq 'sub' ||
               $node->parent()->form() eq 'कि') # Interset also does not know it, the tag is "avy" for both types of conjunctions.
            {
                $node->parent()->set_afun('AuxC');
                $afun = 'Adv';
            }
            else
            {
                $node->set_is_member(1);
            }
        }
        elsif ( $deprel eq "fragof" ) {
            $afun = "Atr";    # modifiers of adjectives.
        }
        elsif ( $deprel eq "enm" ) {
            $afun = "Atr";    # enumerator
        }

        # Some information from POS
        if ( $node->get_iset('pos') eq 'prep' ) {
            $afun = 'AuxP';
        }
        if ( $node->get_iset('subpos') eq 'mod' ) {
            $afun = 'AuxV';
        }

        if ( $cpos eq "VAUX" ) {
            $afun = 'AuxV';
        }
        elsif ( $cpos eq "PSP" ) {
            $afun = 'AuxP';
        }

        if ( $deprel eq "rsym" ) {
            if ( $form eq ',' ) {
                $afun = 'AuxX';
            }
            elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                $afun = 'AuxK';
            }
            elsif ( $form =~ /^(\(|\)|[|]|\$|\%|\=)$/ ) {
                $afun = 'AuxG';
            }
        }
        elsif ( $deprel =~ /^(jjmod_intf|pof__redup|pof__cn|pof__cv|lwg__rest)$/ ) {
            $afun = 'Atr';
        }
        elsif ( $deprel eq "lwg__neg" ) {
            $afun = 'Adv';
        }
        # Postpositions are like prepositions in other languages.
        elsif ( $deprel eq 'lwg__psp' )
        {
            $afun = 'AuxP';
        }
        # Non-first token of compound postposition (e.g. के बाद = ke bāda).
        # Non-first token of compound auxiliary verb (e.g. हो चुके थे = ho cuke the, tagged main lwg__vaux lwg__cont).
        elsif ( $deprel eq 'lwg__cont' )
        {
            # We assume that nodes are processed left-to-right (see get_descendants(ordered) above)
            # and that the left neighbor already has got AuxP or AuxV.
            my $pred = $node->get_left_neighbor();
            if(defined($pred))
            {
                $afun = $pred->afun();
            }
        }

        $node->set_afun($afun);
    }
    # Now that all functions are converted, make sure that functions of coordinations are properly shifted.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            log_fatal("Parentless conjunct") if(!defined($parent));
            $node->set_afun($parent->afun());
            # We have to wait with setting parent's afun to Coord until all conjuncts have copied the parent's original afun.
        }
    }
    # Tag coordination heads as Coord.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            # We have checked that all conjuncts actually have parents.
            $parent->set_afun('Coord');
        }
    }
}



#------------------------------------------------------------------------------
# Reattaches postpositions so that they govern their nouns.
#------------------------------------------------------------------------------
sub raise_postpositions
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Every postposition has the afun 'AuxP' and is attached to a syntactic noun.
        if($node->afun() eq 'AuxP')
        {
            # Most frequent and safest case: only one postposition per noun phrase.
            # If there are two or three it could be compound postposition (see below).
            my @postpositions = grep {$_->afun() eq 'AuxP'} $node->get_siblings({'add_self' => 1, 'ordered' => 1});
            # Also, we assume that the postpositions has no previous children. If it does, something went wrong in the data,
            # or the postposition has been processed previously by this function (in which case it should not be touched again).
            ###!!! But see the training sentence 27 where (in hi_orig) the particle ही depends on the second part of compound postposition से पहले! We currently do not get this right!
            @postpositions = grep {scalar($_->children())==0} (@postpositions);
            if(scalar(@postpositions)>0)
            {
                # We assume that the postposition has parent and grandparent nodes. If not then we cannot reattach it.
                my $parent0 = $postpositions[0]->parent();
                if(defined($parent0))
                {
                    # If the parent is a conjunct, the is_member flag must be moved to the topmost postposition.
                    # (It is the standard in Treex that the node directly under the conjunction bears the flag.
                    # It is unlike in the PDT versions that are distributed to the users.)
                    my $was_member = $parent0->is_member();
                    my $gparent = $parent0->parent();
                    if(defined($gparent))
                    {
                        # Simple postposition with one token.
                        # Examples: में = meṁ = in; पर = para = on
                        # Compound postposition with two tokens (there may be more, I know of at least one example with three).
                        # Example: के बाद = ke bāda = after
                        # Compound postposition with three tokens (I know no example with more but I cannot guarantee it does not exist).
                        # Example: के बरे में = ke bare meṁ = about
                        # The parts of the compound postposition form logically a left-branching chain.
                        # The postposition should be the head of the postpositional phrase.
                        # It should govern the noun phrase. All modifiers of the noun (previously siblings of the postposition)
                        # remain under the noun.
                        for(my $i = 0; $i<$#postpositions; $i++)
                        {
                            $postpositions[$i]->set_parent($postpositions[$i+1]);
                        }
                        $postpositions[-1]->set_parent($gparent);
                        $parent0->set_parent($postpositions[0]);
                        if($was_member)
                        {
                            $postpositions[-1]->set_is_member(1);
                            $parent0->set_is_member(0);
                        }
                    } # if defined $gparent
                } # if defined $parent0
            } # if scalar @postpositions > 0
        } # if afun eq 'AuxP'
    } # foreach $node
}



#------------------------------------------------------------------------------
# Occasionally a comma is not leave. It happens in dates:
# जनवरी, २००१ में
# janavarī, 2001 meṁ
# in January 2001
# Here, "janavarī" is attached to "," ad "mod". This function will reattach it
# to the parent of the comma.
#------------------------------------------------------------------------------
sub raise_children_of_commas
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Warning: Do not approach commas that govern coordinations. Only AuxX please!
        if($node->afun() eq 'AuxX')
        {
            # Check that the comma has a parent (it should!), i.e. that there is somewhere to reattach the children.
            my $parent = $node->parent();
            my @children = $node->children();
            if(defined($parent) && scalar(@children)>=1)
            {
                foreach my $child (@children)
                {
                    $child->set_parent($parent);
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HI::Harmonize

Converts Hindi treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011, 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

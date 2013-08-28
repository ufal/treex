package Treex::Block::A2A::BN::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

#------------------------------------------------------------------------------
# Reads the Bengali CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ltrc.iiit.ac.in/nlptools2010/files/documents/dep-tagset.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
# http://dsal.uchicago.edu/dictionaries/biswas-bengali/
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
        # Note DZ: k1 is karta = agent = usually subject
        if ( $deprel =~ /^(k1|pk1|k4a|r6-k1|ras-k1)$/ ) {
            $afun = "Sb";
        }
        # k1s ... vidheya karta (karta samanadhikarana) = noun complement of karta (according to documentation)
        # আপনি যার কথা বলছেন তার নাম NULL নাগ (training sentence 279)
        # āpani yāra kathā balachena tāra nāma NULL nāga
        # you/dative that word said  his  name (is) snake
        # k1(nāma, NULL)
        # k1s(nāga, NULL)
        # আপনি আমার পূজনীয় NULL
        # āpani  āmāra  pūjanīŷa  NULL
        # you    my     honorable are
        # k1/PRP r6/PRP k1s/JJ    main/NULL
        # => k1s ~ Pnom?
        # আচ্ছা তুমিই বছর আগেকার চিত্রকর নাগ NULL
        # ācchā tumii bachara āgekāra citrakara nāga  NULL
        # but   you   years   earlier painter's snake are
        # ??? - snake of (painter of (earlier by (years)))
        # sent_adv/INJ k1/PRP jjmod/NN nmod/JJ nmod/NN k1s/NNP main/NULL
        elsif ( $deprel =~ m/^(k1s)$/ ) {
            $afun = 'Pnom';
        }
        # k1u is not subject! One verb can have both k1 and k1u but it cannot have two subjects.
        # k1u is missing from the documentation so I do not know what exactly it means.
        # আপনার জামাই আমার দাদার NULL (train sentence 256)
        # āpanāra jāmāi āmāra dādāra NULL
        # your    son   my    grandfather is
        # r6/PRP  k1/NN r6/PRP k1u/NN main/NULL
        # কিন্তু সামন্তের তদ্বিরকারক থাকলে হজমের কাজটা শক্ত হয়ে
        # kintu sāmantera tadbirakāraka thākale hajamera kājatā śakta haŷe
        # main/CC k1u/NNP k1/NN         vmod/VM r6/NN    k1/NN pof/JJ ccof/VM
        # but   suzerain (tadbirakaraka?) if-act/contact/??? metabolic system strong is?
        # মদনা এবার দার্শনিকের প্রশ্ন তুলেছিল
        # madanā ebāra dārśanikera praśna tulechila
        # parrot now   philosopher question tulechila
        # k1/NNP k7t/NN k1u/NN     k2/NN  main/VM
        # সে মানুষের বাঁচতে চায়
        # se mānusera bāmcate cāŷa
        # k1/PRP(se,cāŷa) k1u/NN(mānusera,bāmcate) vmod/VM ?/VAUX
        # he people-of living wants
        # He wants people to live.
        # But here k1 depends on different verb than k1u.
        elsif ( $deprel =~ m/^(k1u)$/ ) {
            $afun = 'Atv'; # or Pnom?
        }
        elsif ( $deprel =~ /^(jk1|mk1)$/ ) {
            $afun = "Obj";
        }
        elsif ( $deprel eq "k1s" ) {
            $afun = "Atv";    # noun complements
        }
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
        # Training sentence 5:
        # ছোটাছুটি করতে
        # choṭāchuṭi karate = to run about
        # choṭāchuṭi = the act/spell of running about (cs:pobíhání)
        # karate = light verb (to do), person 5 (???), tam "A", vibhakti "A_ha+ne"
        # চুমুক দিলেন
        # cumuka dilena = "you sipped"
        # cumuka = noun = "a draught", "a sip"
        # dilena = verb, person = 2, tam = vibhakti = "la" (Wikipedia Bengali grammar: simple past tense, 2/3rd person polite (apni), of দেওয়া deoŷā =? to give
        elsif ( $deprel eq "pof" ) {
            # It would be useful to have a special tag for nominal parts of compound verbs.
            # We do not have it now.
            $afun = 'Obj';
        }
        elsif ( $deprel eq "ccof" ) {
            $node->set_is_member(1);
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
        elsif ( $deprel =~ /^(jjmod_intf|pof__redup|pof__cn|pof__cv|lwg__cont|lwg__rest)$/ ) {
            $afun = 'Atr';
        }
        elsif ( $deprel eq "lwg__neg" ) {
            $afun = 'Adv';
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

1;

=over

=item Treex::Block::A2A::BN::Harmonize

Converts Bengali treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011, 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

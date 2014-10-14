package Treex::Block::HamleDT::TE::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'te::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the Telugu CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($a_root);
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
        if ( $deprel =~ /^(k1|pk1|k4a|r6-k1)$/ )
        {
            $afun = 'Sb';
        }
        # ras-k1 ... associative karta. Not a subject. Someone secondary who assists the subject (asymmetric coordination).
        # (It does not occur in the first training file and it might not occur in Telugu at all.)
        elsif($deprel eq 'ras-k1')
        {
            $afun = 'Adv';
        }
        # k1s ... vidheya karta (karta samanadhikarana) = noun complement of karta (according to documentation)
        # Training sentence 6:
        # మగవాళ్లకంటే ఆడవాళ్లు ఎక్కువ చనిపొతున్నారు
        # magavāḷlakaṁṭe      āḍavāḷlu  èkkuva canipòtunnāru
        # NNplu+vAIYlu_kaMteV NNsingDat NN-adj Vplu3
        # k1u                 k1        k1s    main
        # males-than          women     more   die
        # Women die more than males.
        # (Google: :-)) Magavallakante women more canipotunnaru
        elsif ( $deprel =~ m/^(k1s)$/ )
        {
            $afun = 'Pnom';
        }
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
        # Training sentence 46:
        # ఆడవాళ్లకు ఆపరేషన్లు చేయించాలి
        # āḍavāḷlaku āpareṣanlu ceyiṁcāli
        # k4         pof        main
        # NN         NN         VM
        # women-to   operations should-be-performed
        # Ada      pn pl vib-vAIYlu_ki
        # ApareRan n  pl case-d vib-0 (case-d je asi direct, ne dativ!)
        # ceyiMcu  v  vib/tam-Ali
        elsif ( $deprel eq 'pof' )
        {
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
        if ( $node->get_iset('verbtype') eq 'mod' ) {
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

=item Treex::Block::HamleDT::TE::Harmonize

Converts Telugu treebank into PDT style treebank.

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes


=back

=cut

# Copyright 2011, 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>, Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

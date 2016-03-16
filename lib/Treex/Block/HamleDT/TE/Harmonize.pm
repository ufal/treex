package Treex::Block::HamleDT::TE::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'te::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
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
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    # ICON 2009/2010 CoNLL format uses all three columns but the CPOS column
    # contains chunk tags and we ignore them.
    return "$conll_pos\t$conll_feat";
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://ltrc.iiit.ac.in/nlptools2010/files/documents/dep-tagset.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $form   = $node->form();
        my $pos    = $node->conll_pos();
        my $cpos   = $node->conll_cpos();
        $deprel = 'Atr';    # default assignment if nothing gets assigned

        if ( $deprel eq "main" ) {
            $deprel = "Pred";
        }

        # Subject
        if ( $deprel =~ /^(k1|pk1|k4a|r6-k1)$/ )
        {
            $deprel = 'Sb';
        }
        # ras-k1 ... associative karta. Not a subject. Someone secondary who assists the subject (asymmetric coordination).
        # (It does not occur in the first training file and it might not occur in Telugu at all.)
        elsif($deprel eq 'ras-k1')
        {
            $deprel = 'Adv';
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
            $deprel = 'Pnom';
        }
        elsif ( $deprel =~ m/^(k1u)$/ )
        {
            $deprel = 'Atv'; # or Pnom?
        }
        elsif ( $deprel =~ /^(jk1|mk1)$/ ) {
            $deprel = "Obj";
        }
        elsif ( $deprel eq "k1s" ) {
            $deprel = "Atv";    # noun complements
        }
        elsif ( $deprel =~ /^(k2|k2p|k2g|k2s|k2u|r6-k2|ras-k2)$/ ) {
            $deprel = "Obj";
        }
        elsif ( $deprel eq "k3" ) {
            $deprel = "Adv";    # Instrumental
        }
        elsif ( $deprel eq "k4" || $deprel eq "k4s" ) {
            $deprel = "Obj";    # recipient of the action
        }
        elsif ( $deprel eq "k5" ) {
            $deprel = "Adv";    # source of an activity
        }
        elsif ( $deprel =~ /^(k5prk|k7t|k7p|k7|k7u|vmod)$/ ) {
            $deprel = "Adv";    # reason, location
        }
        elsif ( $deprel =~ /^(r6|r6v)$/ ) {
            $deprel = "Atr";    # genitive
        }
        elsif ( $deprel =~ /^(adv|sent-adv|rd|rh|rt|ras-NEG|rsp|NEG)$/ ) {
            $deprel = "Adv";
        }
        elsif ( $deprel eq "rs" ) {
            $deprel = "Atr";    # noun elaboration ... not sure
        }
        elsif ( $deprel eq "rad" ) {
            $deprel = "Atr";    # address ... not sure
        }
        elsif ( $deprel eq "nmod__relc" || $deprel eq "nmod__adj" ) {
            $deprel = "Atr";    # relative clause modifying noun
        }
        elsif ( $deprel eq "rbmod" || $deprel eq "rbmod__relc" ) {
            $deprel = "Adv";    # relative clause modifying adverb
        }
        elsif ( $deprel eq "jjmod__relc" ) {
            $deprel = "Atr";    # relative clause modifying adjective
        }
        elsif ( $deprel eq "nmod" ) {
            $deprel = "Atr";    # attributes
        }
        elsif ( $deprel eq "jjmod" ) {
            $deprel = "Atr";    # modifiers of adjectives.
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
            $deprel = 'Obj';
        }
        elsif ( $deprel eq "ccof" ) {
            $node->set_is_member(1);
        }
        elsif ( $deprel eq "fragof" ) {
            $deprel = "Atr";    # modifiers of adjectives.
        }
        elsif ( $deprel eq "enm" ) {
            $deprel = "Atr";    # enumerator
        }

        # Some information from POS
        if ( $node->is_adposition() ) {
            $deprel = 'AuxP';
        }
        if ( $node->get_iset('verbtype') eq 'mod' ) {
            $deprel = 'AuxV';
        }

        if ( $cpos eq "VAUX" ) {
            $deprel = 'AuxV';
        }
        elsif ( $cpos eq "PSP" ) {
            $deprel = 'AuxP';
        }

        if ( $deprel eq "rsym" ) {
            if ( $form eq ',' ) {
                $deprel = 'AuxX';
            }
            elsif ( $form =~ /^(\?|\:|\.|\!)$/ ) {
                $deprel = 'AuxK';
            }
            elsif ( $form =~ /^(\(|\)|[|]|\$|\%|\=)$/ ) {
                $deprel = 'AuxG';
            }
        }
        elsif ( $deprel =~ /^(jjmod_intf|pof__redup|pof__cn|pof__cv|lwg__cont|lwg__rest)$/ ) {
            $deprel = 'Atr';
        }
        elsif ( $deprel eq "lwg__neg" ) {
            $deprel = 'Adv';
        }
        $node->set_deprel($deprel);
    }
    # Now that all functions are converted, make sure that functions of coordinations are properly shifted.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            log_fatal("Parentless conjunct") if(!defined($parent));
            $node->set_deprel($parent->deprel());
            # We have to wait with setting parent's deprel to Coord until all conjuncts have copied the parent's original deprel.
        }
    }
    # Tag coordination heads as Coord.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            # We have checked that all conjuncts actually have parents.
            $parent->set_deprel('Coord');
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

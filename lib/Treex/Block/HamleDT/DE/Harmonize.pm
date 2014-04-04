package Treex::Block::HamleDT::DE::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'de::conll2009',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the German tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone( $zone );

    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    # Shifting afuns at prepositions and subordinating conjunctions must be done after coordinations are solved
    # and with special care at places where prepositions and coordinations interact.
    # Prepositional phrases in Tiger are different from most treebanks. That's why we do this in two steps,
    # the first one is Tiger-specific, the second is applied to many treebanks.
    $self->process_tiger_prepositional_phrases($root);
    $self->process_prep_sub_arg_cloud($root);
    $self->mark_deficient_coordination($root);
    $self->rehang_auxc($root);
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
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    # CoNLL 2009 uses only two columns.
    return "$conll_pos\t$conll_feat";
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://www.ims.uni-stuttgart.de/forschung/ressourcen/korpora/TIGERCorpus/annotation/tiger_scheme-syntax.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();
    my $sp_counter = 0;
    foreach my $node (@nodes)
    {

        # The corpus contains the following 46 dependency relation tags:
        # -- AC ADC AG AMS APP AVC CC CD CJ CM CP CVC DA DH DM EP HD JU MNR MO NG NK NMC
        # OA OA2 OC OG OP PAR PD PG PH PM PNC PUNC RC RE ROOT RS SB SBP SP SVP UC VO
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
        my $ppos   = $parent->get_iset('pos');
        my $afun;

        # Dependency of the main verb on the artificial root node.
        if ( $deprel eq 'ROOT' )
        {
            if ( $pos eq 'verb' )
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }

        # Subject.
        elsif ( $deprel eq 'SB' )
        {
            $afun = 'Sb';
        }

        # EP = Expletive (výplňové) es
        # Example: 'es' in constructions 'es gibt X' ('there is X').
        # Formally it is the subject of the verb 'geben'.
        elsif ( $deprel eq 'EP' )
        {
            $afun = 'Sb';
        }

        # Nominal/adjectival predicative.
        elsif ( $deprel eq 'PD' )
        {
            $afun = 'Pnom';
        }

        # Subject or predicative.
        # The parent should have exactly two such arguments. One of them is subject, the other is predicative but we do not know who is who.
        # Our solution: odd occurrences are subjects, even occurrences are predicatives.
        # Note: this occurs only in one sentence of the whole treebank.
        elsif ( $deprel eq 'SP' )
        {
            $sp_counter++;
            if ( $sp_counter % 2 )
            {
                $afun = 'Sb';
            }
            else
            {
                $afun = 'Pnom';
            }
        }

        # Collocational verb construction (Funktionsverbgefüge): combination of full verb and prepositional phrase.
        # Example: in/CVC Schwung/NK bringen
        elsif ( $deprel eq 'CVC' )
        {
            $afun = 'Obj';
        }

        # NK = Noun Kernel (?) = modifiers of nouns?
        # AG = Genitive attribute.
        # PG = Phrasal genitive (a von-PP used instead of a genitive).
        # MNR = Postnominal modifier.
        # PNC = Proper noun component (e.g. first name attached to last name).
        # ADC = Adjective component (e.g. Bad/ADC Homburger, New/ADC Yorker).
        # NMC = Number component (e.g. 20/NMC Millionen/NK Dollar).
        # HD = Head (???) (e.g. Seit/RR über/RR/MO/einem einem/AA/NK/Seit halben/AA/HD/einem Jahr/NN/NK/Seit) (lit: since over a half year)
        #      This example seems to result from an error during conversion of the Tiger constituent structure to dependencies.
        elsif ( $deprel =~ m/^(NK|AG|PG|MNR|PNC|ADC|NMC|HD)$/ )
        {
            $afun = 'Atr';
        }

        # Negation (usually of adjective or verb): 'nicht'.
        elsif ( $deprel eq 'NG' )
        {
            $afun = 'Adv';
        }

        # Measure argument of adjective.
        # Examples: zwei Jahre alt (two years old), zehn Meter hoch (ten meters tall), um einiges besser (somewhat better)
        elsif ( $deprel eq 'AMS' )
        {

            # Inconsistent in PDT, sometimes 'Atr' or even 'Obj' but 'Adv' seems to be the most frequent.
            $afun = 'Adv';
        }

        # Modifier. In NPs only focus particles are annotated as modifiers.
        elsif ( $deprel eq 'MO' )
        {
            if ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $afun = 'AuxZ';
            }
            else
            {
                $afun = 'Adv';
            }
        }

        # Adverb component. Example:
        # Und/J^/AVC zwar/Db/MO jetzt/Db/ROOT !/Z:/PUNC
        elsif ( $deprel eq 'AVC' )
        {
            $afun = 'Adv';
        }

        # Relative clause.
        elsif ( $deprel eq 'RC' )
        {
            if ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $afun = 'Atr';
            }
            else
            {
                $afun = 'Adv';
            }
        }

        # OC = Clausal object. Also verb tokens building a complex verbal form and modal constructions.
        # OA = Accusative object.
        # OA2 = Second accusative object.
        # OG = Genitive object.
        # DA = Dative object or free dative.
        # OP = Prepositional object.
        # SBP = Logical subject in passive construction.
        elsif ( $deprel =~ m/^(OC|OA2?|OG|DA|OP|SBP)$/ )
        {
            $afun = 'Obj';
        }

        # Repeated element.
        # Example:
        # darüber/OP ,/PUNC welche/NK ... wäre/RE (darüber is subtree root, comma and wäre are attached to darüber)
        elsif ( $deprel eq 'RE' )
        {
            $afun = 'Atr';
        }

        # Reported speech (either direct speech in quotation marks or the pattern in the following example).
        # Perot sei/Vc/RS ein autoritärer Macher, beschreibt/VB/ROOT ihn...
        elsif ( $deprel eq 'RS' )
        {
            $afun = 'Obj';
        }

        # CD = Coordinating conjunction.
        # JU = Junctor (conjunction in the beginning of the sentence, deficient coordination).
        elsif ( $deprel =~ m/^(CD|JU)$/ )
        {
            $afun = 'Coord';
            $node->wild()->{coordinator} = 1;
        }

        # Member of coordination.
        elsif ( $deprel eq 'CJ' )
        {
            $afun = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # Second member of apposition.
        elsif ( $deprel eq 'APP' )
        {
            $afun = 'Apposition';
        }

        # Adposition (preposition, postposition or circumposition).
        # If the preposition governs the prepositional phrase, its deprel is that of the whole subtree.
        # However, dependent parts of compound prepositions will get AC.
        # Example: aufgrund/RR von/RR Entscheidungen/NN
        elsif ( $deprel eq 'AC' )
        {
            $afun = 'AuxP';
        }

        # CP = Complementizer (dass)
        # CM = Comparative conjunction
        # CC = Comparative complement
        # This can be a simple noun phrase with conjunction (behaving same way as prepositional phrases):
        # wie Frankreich (like France)
        # It can also be a dependent clause:
        # als/CM dabei gegenwärtige Sünder abgeurteilt werden/CC
        elsif ( $deprel =~ m/^C[MP]$/ )
        {
            $afun = 'AuxC';
        }
        elsif ( $deprel eq 'CC' )
        {
            if ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $afun = 'Atr';
            }
            else
            {
                $afun = 'Adv';
            }
        }

        # PAR = Parenthesis.
        # VO = Vocative.
        # -- = unknown function? First example was a ExD-Pa: WUNSIEDEL, 5. Juli ( dpa/-- ).
        elsif ( $deprel =~ m/^(PAR|VO|--)$/ )
        {
            $afun = 'ExD';
            $node->set_is_parenthesis_root(1);
        }

        # DH = Discourse-level head (with direct speech, information about who said that).
        # It is also used for location information in the beginning of a news report. Example:
        # FR/DH :/PUNC Auf die Wahlerfolge... haben/ROOT die Etablierten... reagiert.
        # In PDT such initial localizations are segmented as separate sentences and get the 'ExD' afun.
        # DM = Discourse marker. Example: 'ja' ('yes'). In PDT, 'ano' ('yes') usually gets 'ExD'.
        elsif ( $deprel =~ m/^D[HM]$/ )
        {
            $afun = 'ExD';
        }

        # PH = Placeholder
        # Example: Vorfeld-es
        # Es naht ein Gewitter. (A storm is coming.)
        # 'Gewitter' is subject, so 'es' cannot be subject.
        elsif ( $deprel eq 'PH' )
        {
            $afun = 'AuxO';
        }

        # Morphological particle: infinitival marker 'zu' with some verb infinitives.
        # The particle is attached to the verb in Tiger treebank.
        # In Danish DT we dealt with infinitive markers 'at' as with subordinating conjunctions. Should we do the same here?
		# BUT: In English, the particle 'to' gets the 'AuxV' afun which is more intuitive (- or is it?), it
		# also avoids leaving 'AuxC' nodes with no children.
        elsif ( $deprel eq 'PM' )
        {
        #    $afun = 'AuxC';
		     $afun = 'AuxV';
        }

        # SVP = Separable verb prefix.
        elsif ( $deprel eq 'SVP' )
        {
            $afun = 'AuxT';
        }

        # Unit component: token in embedded foreign phrase or quotation.
        elsif ( $deprel eq 'UC' )
        {
            $afun = 'Atr';
        }

        # Punctuation.
        elsif ( $deprel eq 'PUNC' )
        {
            if ( $node->form() eq ',' )
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }

            # The sentence-final punctuation should get 'AuxK' but we will also have to reattach it and we will retag it at the same time.
        }
        $node->set_afun($afun);
    }
}



#------------------------------------------------------------------------------
# In Tiger prepositional phrases, not only the noun is attached to the
# preposition, but also all adjectives (that in fact modify the noun).
# Nested prepositional phrases post-modifying the nouns behave similarly.
# Adverbs work as rhematizers and they are also attached to the noun in PDT,
# albeit it creates nonprojectivities.
# There can also be phrases with multiple nouns, one in any prepositional case
# and one in genitive, as:
#     nach einer Umfrage des Fortune Wirtschaftsmagazins unter den Bossen
#     nach < (einer > Umfrage < (des Fortune > Wirtschaftsmagazins) (unter < (den > Bossen)))
# The preposition does not have the 'AuxP' afun.
#------------------------------------------------------------------------------
sub process_tiger_prepositional_phrases
{
    my $self = shift;
    my $root = shift;
    foreach my $node ( $root->get_descendants( { 'ordered' => 1 } ) )
    {
        if ( $node->get_iset('pos') eq 'prep' )
        {
            my @prepchildren = $node->children();
            my $preparg;
            # If there are no children this preposition cannot get the AuxP afun.
            if ( scalar(@prepchildren) == 0 )
            {
                next;
            }
            # Sanity check: A preposition should not work like coordinating conjunction and thus there should be no is_member children.
            # But if they are there, we cannot process it as prepositional phrase, we would violate the coordination constraints!
            elsif ( grep {$_->is_member()} (@prepchildren) )
            {
                next;
            }
            # If there is just one child it is the PrepArg.
            elsif ( scalar(@prepchildren) == 1 )
            {
                $preparg = $prepchildren[0];
            }
            # If there are two or more children we have to estimate which one is the PrepArg.
            # We will assume that the other are in fact modifiers of the PrepArg, not of the preposition.
            else
            {
                # If there are nouns among the children we will pick a noun.
                my @nouns = grep { $_->get_iset('pos') eq 'noun' } (@prepchildren);
                if ( scalar(@nouns) > 0 )
                {
                    # If there are more than one noun we will pick the first one.
                    # This corresponds well to the pattern noun/anyCase + noun/genitive.
                    # However, we must also do something for other sequences of nouns.
                    $preparg = $nouns[0];
                }
                # Otherwise we will just pick the first child.
                else
                {
                    $preparg = $prepchildren[0];
                }
            }
            # Labeling of the preposition and its noun is a complex task and it interferes with other prepositions, subordinating conjunctions and coordinations.
            # We leave it for further processing in process_prep_sub_arg_cloud(). However, we must make sure that the noun is temporarily labeled PrepArg
            # (this is what process_prep_sub_arg_cloud() expects). And more importantly, we must reattach all the other children from the preposition to the noun.
            # Note that we use set_real_afun(), not set_afun(). If the current afun of $preparg is Coord or AuxC, we cannot simply replace it because it would
            # violate other assumptions about the tree!
            $preparg->set_real_afun('PrepArg');
            foreach my $child (@prepchildren)
            {
                unless ( $child == $preparg )
                {
                    $child->set_parent($preparg);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the German
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_moscow($node);
    $coordination->capture_commas();
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_orphans();
    push(@recurse, $coordination->get_children());
    return @recurse;
}



#------------------------------------------------------------------------------
# Deficient sentential coordination is not labeled as coordination in Tiger
# but should be so labeled under the Prague guidelines. We must process it
# separately.
#
# According to PDT annotation manual:
# "4.1.3.6. One-member sentential coordination", conjunctions referring to
# preceding context outside the sentence are often assigned the Coord afun, in
# such cases, they should govern the sentence as if the sentence was the only
# coordination member.
#------------------------------------------------------------------------------
sub mark_deficient_coordination
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        next unless($node->conll_deprel() eq 'JU' && $node->is_leaf() && !$node->is_member());
        my $main = $node->parent();
        next if($main->is_root() || $main->is_member());
        # Make this structure coordination with just one conjunct.
        $node->set_parent($main->parent());
        $node->set_afun('Coord');
        $main->set_parent($node);
        $main->set_is_member(1);
    }
    return;
}



#------------------------------------------------------------------------------
# Adapted from Michal Auersperger's block RehangAuxc:
#Change a-tree from
#"Ob(parent=klappt) das freilich so klappt(parent=ist), ist(parent=root) die Frage."
#to
#"Ob(parent=ist) das freilich so klappt(parent=ob), ist(parent=root) die Frage."
#According to PDT annotation manual: "3.2.7.1.2. Definition of AuxC", subordinating conjunctions should
#govern the subordinate clause and be governed by the head word of the main clause.
#see: http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/a-layer/html/ch03s02x07.html
#German comparative conjunctions (wie, als) should be tagged as subordinating conjunctions and processed
#accordingly.
#------------------------------------------------------------------------------
sub rehang_auxc
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $subord_conj = $node;
        my $parent = $subord_conj->parent();
        # Skip subordinating conjunctions that are members of coordination ("ob und wie sie etwas sichern kann").
        # Skip even those that are shared modifiers of coordination, and those whose parent is member of coordination.
        # There are just a few but reattaching them requires much more care; we could do more wrong than good.
        ###!!! Later we should solve these cases. But without breaking coordination at the same time!
        next if($subord_conj->is_member() || $parent->is_coap_root() || $parent->is_member());
        # Get comparative conjunctions (wie, als), tag them as subord conjunctions and make
        # them govern their parent
        if ($subord_conj->conll_cpos eq 'KOKOM')
        {
            $subord_conj->set_tag('J,-------------'); ###!!! Sakra, tohle se musí udělat v Intersetu!
            # if the parent is member of a CoAp, $subord_conj should govern the whole coordination
            $parent = $parent->get_parent if $parent->is_member; ###!!! Hm a co když je prarodič taky Coord?
            $subord_conj->set_parent( $parent->get_parent() );
            $parent->set_parent($subord_conj);
        }
        elsif ($subord_conj->afun eq 'AuxC' and $subord_conj->tag =~ /^J,.*/ and $subord_conj->is_leaf) ###!!! Interset!
        {
            # if the parent is member of a CoAp, $subord_conj should govern the whole coordination
            $parent = $parent->get_parent if $parent->is_member; ###!!! Hm a co když je prarodič taky Coord?
            $subord_conj->set_parent( $parent->get_parent() );
            $parent->set_parent($subord_conj);
        }
    }
    return;
}



1;

=over

=item Treex::Block::HamleDT::DE::Harmonize

Converts Tiger trees from CoNLL to the HamleDT (Prague) style.
Morphological tags will be decoded into Interset and to the 15-character positional tags of PDT.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

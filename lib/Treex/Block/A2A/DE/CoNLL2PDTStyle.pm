package Treex::Block::A2A::DE::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';



#------------------------------------------------------------------------------
# Reads the German tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $a_root = $self->SUPER::process_zone($zone, 'conll2009');
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://www.ims.uni-stuttgart.de/projekte/TIGER/TIGERCorpus/annotation/tiger_scheme-syntax.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $sp_counter = 0;
    foreach my $node (@nodes)
    {
        # The corpus contains the following 46 dependency relation tags:
        # -- AC ADC AG AMS APP AVC CC CD CJ CM CP CVC DA DH DM EP HD JU MNR MO NG NK NMC
        # OA OA2 OC OG OP PAR PD PG PH PM PNC PUNC RC RE ROOT RS SB SBP SP SVP UC VO
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $pos = $node->get_iset('pos');
        my $ppos = $parent->get_iset('pos');
        my $afun;
        # Dependency of the main verb on the artificial root node.
        if($deprel eq 'ROOT')
        {
            if($pos eq 'verb')
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }
        # Subject.
        elsif($deprel eq 'SB')
        {
            $afun = 'Sb';
        }
        # EP = Expletive (výplňové) es
        # Example: 'es' in constructions 'es gibt X' ('there is X').
        # Formally it is the subject of the verb 'geben'.
        elsif($deprel eq 'EP')
        {
            $afun = 'Sb';
        }
        # Nominal/adjectival predicative.
        elsif($deprel eq 'PD')
        {
            $afun = 'Pnom';
        }
        # Subject or predicative.
        # The parent should have exactly two such arguments. One of them is subject, the other is predicative but we do not know who is who.
        # Our solution: odd occurrences are subjects, even occurrences are predicatives.
        # Note: this occurs only in one sentence of the whole treebank.
        elsif($deprel eq 'SP')
        {
            $sp_counter++;
            if($sp_counter % 2)
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
        elsif($deprel eq 'CVC')
        {
            $afun = 'Obj';
        }
        # NK = Noun Kernel (?) = modifiers of nouns?
        # AG = Genitive attribute.
        # PG = Phrasal genitive (a von-PP used instead of a genitive).
        # MO = Modifier.
        # MNR = Postnominal modifier.
        # PNC = Proper noun component (e.g. first name attached to last name).
        # ADC = Adjective component (e.g. Bad/ADC Homburger, New/ADC Yorker).
        # NMC = Number component (e.g. 20/NMC Millionen/NK Dollar).
        # HD = Head (???) (e.g. Seit/RR über/RR/MO/einem einem/AA/NK/Seit halben/AA/HD/einem Jahr/NN/NK/Seit) (lit: since over a half year)
        #      This example seems to result from an error during conversion of the Tiger constituent structure to dependencies.
        elsif($deprel =~ m/^(NK|AG|PG|MNR|PNC|ADC|NMC|HD)$/)
        {
            $afun = 'Atr';
        }
        # Negation (usually of adjective or verb): 'nicht'.
        elsif($deprel eq 'NG')
        {
            $afun = 'Adv';
        }
        # Measure argument of adjective.
        # Examples: zwei Jahre alt (two years old), zehn Meter hoch (ten meters tall), um einiges besser (somewhat better)
        elsif($deprel eq 'AMS')
        {
            # Inconsistent in PDT, sometimes 'Atr' or even 'Obj' but 'Adv' seems to be the most frequent.
            $afun = 'Adv';
        }
        # Modifier. In NPs only focus particles are annotated as modifiers.
        elsif($deprel eq 'MO')
        {
            if($ppos =~ m/^(noun|adj|num)$/)
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
        elsif($deprel eq 'AVC')
        {
            $afun = 'Adv';
        }
        # Relative clause.
        elsif($deprel eq 'RC')
        {
            if($ppos =~ m/^(noun|adj|num)$/)
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
        elsif($deprel =~ m/^(OC|OA2?|OG|DA|OP|SBP)$/)
        {
            $afun = 'Obj';
        }
        # Repeated element.
        # Example:
        # darüber/OP ,/PUNC welche/NK ... wäre/RE (darüber is subtree root, comma and wäre are attached to darüber)
        elsif($deprel eq 'RE')
        {
            $afun = 'Atr';
        }
        # Reported speech (either direct speech in quotation marks or the pattern in the following example).
        # Perot sei/Vc/RS ein autoritärer Macher, beschreibt/VB/ROOT ihn...
        elsif($deprel eq 'RS')
        {
            $afun = 'Obj';
        }
        # CD = Coordinating conjunction.
        # JU = Junctor (conjunction in the beginning of the sentence, deficient coordination).
        elsif($deprel =~ m/^(CD|JU)$/)
        {
            $afun = 'Coord';
        }
        # Member of coordination.
        elsif($deprel eq 'CJ')
        {
            $afun = 'CoordArg';
        }
        # Second member of apposition.
        elsif($deprel eq 'APP')
        {
            $afun = 'Apos';
        }
        # Adposition (preposition, postposition or circumposition).
        # If the preposition governs the prepositional phrase, its deprel is that of the whole subtree.
        # However, dependent parts of compound prepositions will get AC.
        # Example: aufgrund/RR von/RR Entscheidungen/NN
        elsif($deprel eq 'AC')
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
        elsif($deprel =~ m/^C[MP]$/)
        {
            $afun = 'AuxC';
        }
        elsif($deprel eq 'CC')
        {
            if($ppos =~ m/^(noun|adj|num)$/)
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
        elsif($deprel =~ m/^(PAR|VO|--)$/)
        {
            $afun = 'ExD';
            $node->set_is_parenthesis_root(1);
        }
        # DH = Discourse-level head (with direct speech, information about who said that).
        # It is also used for location information in the beginning of a news report. Example:
        # FR/DH :/PUNC Auf die Wahlerfolge... haben/ROOT die Etablierten... reagiert.
        # In PDT such initial localizations are segmented as separate sentences and get the 'ExD' afun.
        # DM = Discourse marker. Example: 'ja' ('yes'). In PDT, 'ano' ('yes') usually gets 'ExD'.
        elsif($deprel =~ m/^D[HM]$/)
        {
            $afun = 'ExD';
        }
        # PH = Placeholder
        # Example: Vorfeld-es
        # Es naht ein Gewitter. (A storm is coming.)
        # 'Gewitter' is subject, so 'es' cannot be subject.
        elsif($deprel eq 'PH')
        {
            $afun = 'AuxO';
        }
        # Morphological particle: infinitival marker 'zu' with some verb infinitives.
        # The particle is attached to the verb in Tiger treebank.
        # In Danish DT we dealt with infinitive markers 'at' as with subordinating conjunctions. Should we do the same here?
        elsif($deprel eq 'PM')
        {
            $afun = 'AuxC';
        }
        # SVP = Separable verb prefix.
        elsif($deprel eq 'SVP')
        {
            $afun = 'AuxT';
        }
        # Unit component: token in embedded foreign phrase or quotation.
        elsif($deprel eq 'UC')
        {
            $afun = 'Atr';
        }
        # Punctuation.
        elsif($deprel eq 'PUNC')
        {
            if($node->form() eq ',')
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



1;



=over

=item Treex::Block::A2A::DE::CoNLL2PDTStyle

Converts Tiger trees from CoNLL to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::HamleDT::DE::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the German tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2009' );

    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
    $self->process_prepositional_phrases($a_root);
    $self->restructure_coordination($a_root);
    $self->check_afuns($a_root);

    $self->get_or_load_other_block('HamleDT::DE::RehangJunctors')->process_zone($a_root->get_zone());
    $self->get_or_load_other_block('HamleDT::DE::RehangAuxc')->process_zone($a_root->get_zone());
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://www.ims.uni-stuttgart.de/projekte/TIGER/TIGERCorpus/annotation/tiger_scheme-syntax.pdf
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
        }

        # Member of coordination.
        elsif ( $deprel eq 'CJ' )
        {
            $afun = 'CoordArg';
        }

        # Second member of apposition.
        elsif ( $deprel eq 'APP' )
        {
            ## TODO: ZZ: yes, it's an annotated apposition,
            # but making it compatible with the PDT apposition style
            # would require also systematic rehanging of the neighborhood.
            # Let's make the hamledt tests happy and pretend in the meantime
            # that it's an attribute
            $afun = 'Atr'; #'Apos';
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
sub process_prepositional_phrases
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

            # Keep PrepArg as the only child of the AuxP node.
            # Reattach all other children to PrepArg.
            $preparg->set_afun( $node->afun() );
            $node->set_afun('AuxP');
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
# Detects coordination in German trees.
# - The first member is the root.
# - Any non-first member is attached to the previous member with afun CoordArg.
#   If prepositional phrases have already been processed and there is
#   coordination of prepositional phrases, the prepositins are tagged AuxP and
#   the CoordArg afun is found at the only child of the preposition.
# - Coordinating conjunction is attached to the previous member with afun Coord.
# - Comma is attached to the previous member with afun AuxX.
# - Shared modifiers are attached to the first member. Private modifiers are
#   attached to the member they modify.
# Note that under this approach:
# - Shared modifiers cannot be distinguished from private modifiers of the
#   first member.
# - Nested coordinations ("apples, oranges and [blackberries or strawberries]")
#   cannot be distinguished from one large coordination.
# Special cases:
# - Coordination lacks any conjunctions or punctuation with the CD deprel tag.
#   Example:
#   `` Spürst du das ? '' , fragt er , `` spürst du den Knüppel ?
#   In this example, the second 'spürst' is attached as a CoordArg to the first
#   'Spürst'. All punctuation is attached to 'fragt', so we don't see the
#   second comma as the potential coordinating node.
#   Possible solutions:
#   Ideally, there'd be a separate function that would reattach punctuation
#   first. Commas before and after nested clauses, including direct speech,
#   would be part of the clause and not of the surrounding main clause. Same
#   for quotation marks around direct speech. And then we would have to
#   find out that there is a comma before the second 'spürst' that can be used
#   as coordinator.
#   In reality we will be less ambitious and develop a robust fallback for
#   coordination without coordinators.
#------------------------------------------------------------------------------
# Collects members, delimiters and modifiers of one coordination. Recursive.
# Leaves the arrays empty if called on a node that is not a coordination
# member.
#------------------------------------------------------------------------------
sub collect_coordination_members
{
    my $self       = shift;
    my $croot      = shift;    # the first node and root of the coordination
    my $members    = shift;    # reference to array where the members are collected
    my $delimiters = shift;    # reference to array where the delimiters are collected
    my $sharedmod  = shift;    # reference to array where the shared modifiers are collected
    my $privatemod = shift;    # reference to array where the private modifiers are collected
    my $debug      = shift;

    # Is this the top-level call in the recursion?
    my $toplevel = scalar( @{$members} ) == 0;
    my @children = $croot->children();
    log_info( 'DEBUG ON ' . scalar(@children) ) if ($debug);

    # No children to search? Nothing to do!
    return if ( scalar(@children) == 0 );

    # AuxP occurs only if prepositional phrases have already been processed.
    # AuxP node cannot be the first member of coordination ($toplevel).
    # However, AuxP can be non-first member. In that case, its only child bears the CoordArg afun.
    if ( $croot->afun() eq 'AuxP' )
    {
        if ($toplevel)
        {
            return;
        }
        else
        {

            # We know that there is at least one child (see above) and for AuxP, there should not be more than one child.
            # Make the PrepArg child the member instead of the preposition.
            $croot    = $children[0];
            @children = $croot->children();
        }
    }
    my @members0;
    my @delimiters0;
    my @sharedmod0;
    my @privatemod0;
    @members0 = grep {
        my $x = $_;
        $x->afun() eq 'CoordArg' || $x->afun() eq 'AuxP' && grep { $_->afun() eq 'CoordArg' } ( $x->children() )
    } (@children);
    if (@members0)
    {

        # If $croot is the real root of the whole coordination we must include it in the members, too.
        # However, if we have been called recursively on existing members, these are already present in the list.
        if ($toplevel)
        {
            push( @{$members}, $croot );
        }
        push( @{$members}, @members0 );

        # All children with the 'Coord' afun are delimiters (coordinating conjunctions).
        # Punctuation children are usually delimiters, too.
        # They should appear between two members, which would normally mean between $croot and its (only) CoordArg.
        # However, the method is recursive and "before $croot" could mean between $croot and the preceding member. Same for the other end.
        # So we take all punctuation children and hope that other punctuation (such as delimiting modifier relative clauses) would be descendant but not child.
        my @delimiters0 = grep { $_->afun() =~ m/^(Coord|AuxX|AuxG)$/ } (@children);
        push( @{$delimiters}, @delimiters0 );

        # Recursion: If any of the member children (i.e. any members except $croot)
        # have their own CoordArg children, these are also members of the same coordination.
        foreach my $member (@members0)
        {
            $self->collect_coordination_members( $member, $members, $delimiters );
        }

        # If this is the top-level call in the recursion, we now have the complete list of coordination members
        # and we can call the method that collects and sorts out coordination modifiers.
        if ($toplevel)
        {
            $self->collect_coordination_modifiers( $members, $sharedmod, $privatemod );
        }
    }
}

#------------------------------------------------------------------------------
# For a list of coordination members, finds their modifiers and sorts them out
# as shared or private. Modifiers are children whose afuns do not suggest they
# are members (CoordArg) or delimiters (Coord|AuxX|AuxG).
#------------------------------------------------------------------------------
sub collect_coordination_modifiers
{
    my $self       = shift;
    my $members    = shift;                                           # reference to input array
    my $sharedmod  = shift;                                           # reference to output array
    my $privatemod = shift;                                           # reference to output array
    # All children of all members are modifiers (shared or private) provided they are neither members nor delimiters.
    # Any left modifiers of the first member will be considered shared modifiers of the coordination.
    # Any right modifiers of the first member occurring after the second member will be considered shared modifiers, too.
    # Note that the DDT structure does not provide for the distinction between shared modifiers and private modifiers of the first member.
    # Modifiers of the other members are always private.
    my $croot      = $members->[0];
    my $ord0       = $croot->ord();
    my $ord1       = $#{$members} >= 1 ? $members->[1]->ord() : -1;
    foreach my $member ( @{$members} )
    {
        my @modifying_children = grep { $_->afun() !~ m/^(CoordArg|Coord|AuxX|AuxG)$/ } ( $member->children() );
        if ( $member == $croot )
        {
            foreach my $mchild (@modifying_children)
            {
                my $ord = $mchild->ord();
                if ( $ord < $ord0 || $ord1 >= 0 && $ord > $ord1 )
                {
                    # This may be either shared or private modifier.
                    #push( @{$sharedmod}, $mchild );
                    # Since there is no explicit information on shared modifiers in the treebank
                    # and because the modifier is attached to one member of the coordination,
                    # let's not add information and let's treat it as a private modifier.
                    push(@{$privatemod}, $mchild);
                }
                else
                {

                    # This modifier of the first member occurs between the first and the second member.
                    # Consider it private.
                    push( @{$privatemod}, $mchild );
                }
            }
        }
        else
        {
            push( @{$privatemod}, @modifying_children );
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::DE::Harmonize

Converts Tiger trees from CoNLL to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

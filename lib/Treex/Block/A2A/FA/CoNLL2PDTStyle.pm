package Treex::Block::A2A::FA::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';



#------------------------------------------------------------------------------
# Reads the Persian tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll' );

    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
    $self->process_prepositional_phrases($a_root);
    $self->restructure_coordination($a_root);
    $self->check_afuns($a_root);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# https://wiki.ufal.ms.mff.cuni.cz/_media/user:zeman:treebanks:persian-dependency-treebank-version-0.1-annotation-manual-and-user-guide.pdf
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
        # The corpus contains the following 44 dependency relation tags:
        # SBJ OBJ NVE ENC VPP OBJ2 TAM MOS PROG ADVC VCL VPRT LVP PARCL ADV AJUCL PART VCONJ
        # NPREMOD NPOSTMOD NPP NCL MOZ APP NCONJ NADV NE MESU NPRT COMPPP ADJADV ACL AJPP NEZ AJCONJ APREMOD APOSTMOD
        # PREDEP POSDEP PCONJ AVCONJ PRD ROOT PUNC
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
        # PRD: Predicate of a subordinate or relative clause, attached to the subordinating conjunction.
        #     Example: amädäm ta bebinäm = I-came to I-see = I came to see (bebinäm is PRD of ta).
        elsif ( $deprel eq 'PRD' )
        {
            $afun = 'Pred';
        }
        # Subject.
        elsif ( $deprel eq 'SBJ' )
        {
            $afun = 'Sb';
        }
        # OBJ:  Object.
        # VPP:  Prepositional complement of verb (this is the label of the preposition, so ve also need to switch it with the NP later).
        # VPRT: Sometimes preposition-noun-verb is considered a compound verb. Then the preposition is VPRT: be däst avärd = to hand brought = gained.
        # LVP:  Light verb particle. Only the compound light verb "pejda kärdän" (to find) (pejda is LVP).
        # VCL:  Complement clause of verb: midanäm ke miajäd = I know that he comes.
        # NPRT: Particle (preposition) of infinitive (infinitives behave as nouns in Persian).
        # ACL:  Complement clause of adjective: agah hästäm ke miaji = aware am that he-comes = I am aware that he will come.
        # AJPP: Prepositional complement of adjective: ašna ba äkkasi = familiar with photography.
        # NEZ:  Ezafe complement of adjective (see MOZ below for ezafe explanation): negäran-e u = anxious-EZAFE him = anxious about him.
        elsif ( $deprel =~ m/^(OBJ2?|VPP|VPRT|VCL|ACL|AJPP|NEZ)$/ )
        {
            $afun = 'Obj';
        }
        # NVE: Non-verbal element of a compound verb (compound predicate).
        # ENC: Enclitic non-verbal element of a compound verb.
        # MOS: Mosnad. A property ascribed to the subject using verbs such as šodän (to become), budän (to be), ästän (to be) etc.
        #      Example: u  doktor äst
        #      Gloss:   he doctor is
        # NE: Non-verbal element of compound infinitive (Persian infinitives behave (and are tagged?) as nouns).
        elsif ( $deprel =~ m/^(NVE|ENC|MOS|NE)$/ )
        {
            $afun = 'Pnom';
        }
        # TAM: Tamiz: a property ascribed by the subject to the object (simplified).
        # Typically occurs with verbs like namidän (to name), xandän (to call), danestän (to consider) etc.
        # Example: ali ra märd -i xub mipendarim
        # Gloss: Ali ACC man INDEF good consider/PRES-1ST-PL
        # Translation: We consider Ali a good man.
        # The relation between "mipendarim" and "xub" is labeled "TAM".
        elsif ( $deprel eq 'TAM' )
        {
            $afun = 'Atv';
        }
        # ADVC: Adverbial complement of verb: tehran mandäm = Tehran stay/PAST-1ST-SG = I stayed in Tehran.
        # ADV: Adverbial modifier of verb: bäraje xärid räftäm = for shopping I-went = I went for shopping.
        # AJUCL: Adjunct clause: ägär bijaji xošhal mišäväm = if you-come happy I-become = I'll be happy if you come. (ägär is AJUCL)
        # PARCL: Participle clause.
        #    In coordination of two verbs with the same subject and different verbs of the same tense-aspect-mood,
        #    the first verb can be changed into the past participle form. In such a case, the transformed verb
        #    depends on the verb with normal inflection and the relation is labeled PARCL.
        #    Example: be xane räfte xabidäm = to home gone I slept = I went home and slept (or: Having gone home, I slept)
        # NADV: Adverbial modifier of compound predicate, attached to its non-verb component.
        # ADJADV: Adverbial complement of adjective: taksi sävar šodäm = taxi riding I-became (taksi is ADJADV of sävar).
        # APREMOD: Adjective pre-modifier by an adverb: besjar šad = very happy.
        # APOSTMOD: Adjective post-modifier by another adjective: pirahän-e abi-je asemani = shirt-EZAFE blue-EZAFE sky = a sky blue shirt.
        elsif ( $deprel =~ m/^(ADVC|ADV|AJUCL|PARCL|NADV|ADJADV|APREMOD|APOSTMOD)$/ )
        {
            $afun = 'Adv';
        }
        # PROG: Auxiliary forming the progressive tense.
        # Example:     daštäm           miräštäm
        # Gloss:       have-PAST-1ST-SG go-PAST-PROG-1ST-SG
        # Translation: I was going.
        # Daštäm is the auxiliary.
        elsif ( $deprel eq 'PROG' )
        {
            $afun = 'AuxV';
        }
        # PART: Interrogative particle.
        #     The words "aja" and "mägär" turn the sentence into a yes/no question.
        #     The relation between the main verb and these particles is labeled "PART".
        elsif ( $deprel eq 'PART' )
        {
            # The Czech PDT tagset does not seem to provide a better label than AuxV.
            # There might be something in the Arabic PADT: AuxM?
            $afun = 'AuxV';
        }
        # NPREMOD: Pre-modifier of noun (superlative adjective, numeral, title).
        # NPOSTMOD: Post-modifier of noun (positive and comparative adjective, numeral).
        # NPP: Prepositional phrase modifying a noun, e.g.: jedal dar tasuki = battle in Tasooki
        # NCL: Clause modifying a noun, e.g.: märd -i ke didi = man a that you-saw = the man you saw
        # MOZ: Ezafe dependent.
        #    Ezafe is the suffix "-e" pronounced after a Persian noun, usually not visible in the Perso-Arabic script (=> it has no node in the tree).
        #    It signifies an ezafe construction that connects the head noun to the following modifier noun (cf. with pre/postpositions).
        #    Its possible meanings are:
        #        - possession: ketab-e häsän = book of Hassan = Hassan's book
        #        - first name - last name
        #        - etc.
        #    Ezafe dependent is the noun after ezafe.
        # MESU: Measure (a measurement unit between numeral and counted noun): do dželd ketab = two volume book
        elsif ( $deprel =~ m/^(NPREMOD|NPOSTMOD|NPP|NCL|MOZ)$/ )
        {
            $afun = 'Atr';
        }
        # COMPPP: Comparative preposition: behtär äz servät = better than wealth; äz is COMPPP of behtär.
        #     http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s07s09s02.html
        #     In PDT, comparative constructions "better than something" are analyzed as ellipsis for "better than something is".
        #     They are thus tagged 'ExD', which does not say much (many other very different cases are tagged 'ExD', too).
        #     We may want to consider introducing special afun for comparative constructions instead.
        elsif ( $deprel eq 'COMPPP' )
        {
            $afun = 'ExD';
        }
        # PREDEP: Pre-dependent in cases that do not have their own specific tag.
        #     Most common: relation between a noun and its accusative postposition "-ra": äli -ra didäm = Ali ACC I-saw = I saw Ali (äli is PREDEP of -ra).
        #     Also common: between coordinating conjunction and the preceding (non-head): xandäm vä neveštäm = I-read and I-wrote (xandäm is PREDEP of vä).
        # POSDEP: Post-dependent in cases that do not have their own specific tag.
        #     Common use: relation between a preposition and its noun: be äli = to Ali (äli is POSDEP of be).
        elsif ( $deprel =~ m/^(PREDEP|POSDEP)$/ )
        {
            $afun = 'PrepArg';
        }
        # VCONJ: Coordinating conjunction between two verbs (the one appearing earlier is dependent, the one appearing later is the head)
        # or the dependent verb conjunct if there is no coordinating conjunction.
        # NCONJ: Same for nouns.
        # AJCONJ: Same for adjectives.
        # PCONJ: Same for prepositions: där tehran vä ba ma bud = in Tehran and with us was = he was in Tehran and with us (där is PCONJ of vä).
        # AVCONJ: Same for adverbs.
        elsif ( $deprel =~ m/^(VCONJ|NCONJ|AJCONJ|PCONJ|AVCONJ)$/ )
        {
            $afun = 'Coord';
        }
        # Second member of apposition: sädi šaer -e irani = Saadi poet EZAFE Iranian = Saadi, the Iranian poet
        elsif ( $deprel eq 'APP' )
        {
            $afun = 'Apos';
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

=item Treex::Block::A2A::FA::CoNLL2PDTStyle

Converts Persian dependency trees from CoNLL to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

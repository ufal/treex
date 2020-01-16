package Treex::Block::A2A::AddEnhancedUD;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'case'  => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'enhance oblique relation labels by case information' );
has 'coord' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'propagate shared parents and dependents across coordination' );
has 'xsubj' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'add relations to external subjects of open clausal complements' );
has 'relcl' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'transform relations between relative clauses and their modified nominals' );
has 'empty' => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'add empty nodes where there are orphans in basic tree' );



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # We assume that the basic tree has been copied to the enhanced graph
    # (see the block A2A::CopyBasicToEnhanced). The enhanced graph is stored
    # in the wild attributes of nodes. Each node should now have the wild
    # attribute 'enhanced', which is a list of pairs, where each pair contains:
    # - the ord of the parent node
    # - the type of the relation between the parent node and this node
    # We do not store the Perl reference to the parent node in order to prevent cyclic references and issues with garbage collection.
    my @nodes = $root->get_descendants({'ordered' => 1});
    # First enhance all oblique relations with case information. If we later
    # copy those relations in other transformations, we want to be sure that
    # it all have been enhanced.
    if($self->case())
    {
        foreach my $node (@nodes)
        {
            if(!exists($node->wild()->{enhanced}))
            {
                log_fatal("The wild attribute 'enhanced' does not exist.");
            }
            $self->add_enhanced_case_deprel($node); # call this before coordination and relative clauses
        }
    }
    # Process all relations that shall be propagated across coordination before
    # proceeding to the next enhancement type.
    if($self->coord())
    {
        foreach my $node (@nodes)
        {
            $self->add_enhanced_parent_of_coordination($node);
            $self->add_enhanced_shared_dependent_of_coordination($node);
        }
    }
    # Add external subject relations in control verb constructions.
    if($self->xsubj())
    {
        my @visited_xsubj;
        foreach my $node (@nodes)
        {
            $self->add_enhanced_external_subject($node, \@visited_xsubj);
        }
    }
    # Process all relations affected by relative clauses before proceeding to
    # the next enhancement type. Calling this after the coordination enhancement
    # enables us to transform also coordinate relative clauses or modified nouns.
    if($self->relcl())
    {
        foreach my $node (@nodes)
        {
            $self->add_enhanced_relative_clause($node);
        }
        foreach my $node (@nodes)
        {
            $self->remove_enhanced_non_ref_relations($node);
        }
    }
    # Generate empty nodes instead of orphan relations.
    if($self->empty())
    {
        my %emptynodes;
        foreach my $node (@nodes)
        {
            $self->add_enhanced_empty_node($node, \%emptynodes);
        }
    }
}



#------------------------------------------------------------------------------
# Adds case information to selected relation types. This function should be
# called before we propagate dependencies across coordination, as some of the
# labels that we enhance here will be later copied to new dependencies. For the
# same reason this function should be also called before adding relations back
# from a relative clause to the modified nominal. Interaction with gapping is
# less clear. The gapping-resolving algorithm will tell us that an orphan is
# "obl" or "advcl", but its case information may actually differ from that
# found at the overtly represented predicate.
#------------------------------------------------------------------------------
sub add_enhanced_case_deprel
{
    my $self = shift;
    my $node = shift;
    foreach my $edep (@{$node->wild()->{enhanced}})
    {
        my $eparent = $edep->[0];
        my $edeprel = $edep->[1];
        # We use paths to represent empty nodes in Treex, e.g., '0:root>34.1>cc'
        # means that there should be a root edge from 0 to 34.1, and a cc edge
        # from 34.1 to the actual node. If the graph already contains such edges,
        # do not touch them, we do not want to destroy them!
        next if($edeprel =~ m/>/);
        # The guidelines allow enhancing nmod, acl, obl and advcl.
        # If it makes sense in the language, core relations obj, iobj and ccomp can be enhanced too.
        # Sebastian's enhancer further enhances conj relations with the lemma of the conjunction, but it is not supported in the guidelines.
        next unless($edeprel =~ m/^(nmod|acl|obl|advcl)(:|$)/);
        # Collect case and mark children. We are modifying the enhanced deprel
        # but we look for input solely in the basic tree.
        ###!!! That means that we may not be able to find a preposition shared by conjuncts.
        ###!!! Finding it would need more work anyways, because we call this function before we propagate dependencies across coordination.
        my @children = $node->children({'ordered' => 1});
        my @casemark = grep {$_->deprel() =~ m/^(case|mark)(:|$)/} (@children);
        # If the current constituent is a clause, take mark dependents but not case dependents.
        # This may not work the same way in all languages, as e.g. in Swedish Joakim uses case even with clauses.
        # However, in Czech-PUD this will help us to skip prepositions under a nominal predicate, which modify the nominal but not the clause:
        # "kandidáta, který byl v pořadí za ním" ("candidate who was after him"): avoid the preposition "za"
        if($edeprel =~ m/^(acl|advcl)(:|$)/)
        {
            @casemark = grep {$_->deprel() !~ m/^case(:|$)/} (@casemark);
        }
        # For each of the markers check whether it heads a fixed expression.
        my @cmlemmas = grep {defined($_)} map
        {
            my $x = $_;
            my @fixed = grep {$_->deprel() =~ m/^(fixed)(:|$)/} ($x->children({'ordered' => 1}));
            my $l = lc($x->lemma());
            if(defined($l) && ($l eq '' || $l eq '_'))
            {
                $l = undef;
            }
            if(defined($l))
            {
                $l = lc($l);
                if(scalar(@fixed) > 0)
                {
                    $l .= '_' . join('_', map {lc($_->lemma())} (@fixed));
                }
            }
            $l;
        }
        (@casemark);
        my $cmlemmas = join('_', @cmlemmas);
        # Only selected characters are allowed in lemmas of case markers.
        # For example, digits and punctuation symbols (except underscore) are not allowed.
        $cmlemmas =~ s/[^\p{Ll}\p{Lm}\p{Lo}\p{M}_]//g;
        $cmlemmas =~ s/^_+//;
        $cmlemmas =~ s/_+$//;
        $cmlemmas =~ s/_+/_/g;
        $cmlemmas = undef if($cmlemmas eq '');
        if(defined($cmlemmas))
        {
            $edeprel .= ":$cmlemmas";
        }
        # Look for morphological case only if this is a nominal and not a clause.
        if($edeprel =~ m/^(nmod|obl)(:|$)/)
        {
            # In Slavic and some other languages, the case of a quantified phrase may
            # be determined by the quantifier rather than by the quantified head noun.
            # We can recognize such quantifiers by the relation nummod:gov or det:numgov.
            my @qgov = grep {$_->deprel() =~ m/^(nummod:gov|det:numgov)$/} (@children);
            my $qgov = scalar(@qgov);
            # There is probably just one quantifier. We do not have any special rule
            # for the possibility that there are more than one.
            my $caseiset = $qgov ? $qgov[0]->iset() : $node->iset();
            my $case = $caseiset->case();
            if(ref($case) eq 'ARRAY')
            {
                $case = $case->[0];
            }
            if(defined($case) && $case ne '')
            {
                $edeprel .= ':'.lc($case);
            }
        }
        # Store the modified enhanced deprel back to the wild attributes.
        $edep->[1] = $edeprel;
    }
}



#------------------------------------------------------------------------------
# Propagates parent of coordination to all conjuncts.
#------------------------------------------------------------------------------
sub add_enhanced_parent_of_coordination
{
    my $self = shift;
    my $node = shift;
    my @edeps = $self->get_enhanced_deps($node);
    if(any {$_->[1] =~ m/^conj(:|$)/} (@edeps))
    {
        my @edeps_to_propagate;
        # Find the nearest non-conj ancestor, i.e., the first conjunct.
        my @eparents = $self->get_enhanced_parents($node, '^conj(:|$)');
        # There should be normally at most one conj parent for any node. So we take the first one and assume it is the only one.
        log_fatal("Did not find the 'conj' enhanced parent.") if(scalar(@eparents) == 0);
        my $inode = $eparents[0];
        while(defined($inode))
        {
            @eparents = $self->get_enhanced_parents($inode, '^conj(:|$)');
            if(scalar(@eparents) == 0)
            {
                # There are no higher conj parents. So we will now look for the non-conj parents. Those are the relations we want to propagate.
                @edeps_to_propagate = grep {$_->[1] !~ m/^conj(:|$)/} ($self->get_enhanced_deps($inode));
                last;
            }
            $inode = $eparents[0];
        }
        if(defined($inode))
        {
            foreach my $edep (@edeps_to_propagate)
            {
                $self->add_enhanced_dependency($node, $self->get_node_by_ord($node, $edep->[0]), $edep->[1]);
                # The coordination may function as a shared dependent of other coordination.
                # In that case, make me depend on every conjunct in the parent coordination.
                if($inode->is_shared_modifier())
                {
                    my @conjuncts = $self->recursively_collect_conjuncts($self->get_node_by_ord($node, $edep->[0]));
                    foreach my $conjunct (@conjuncts)
                    {
                        $self->add_enhanced_dependency($node, $conjunct, $edep->[1]);
                    }
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Propagates shared dependent of coordination to all conjuncts.
#------------------------------------------------------------------------------
sub add_enhanced_shared_dependent_of_coordination
{
    my $self = shift;
    my $node = shift;
    # Exclude shared "modifiers" whose deprel is 'cc'. They probably just help
    # delimit the coordination. (In nested coordination "A - B and C - D", the
    # conjunction 'and' would come out as a shared 'cc' dependent of 'C' and 'D'.)
    # Note: If the shared dependent itself is coordination, all conjuncts
    # should have the flag is_shared_modifier. (At least I have now checked
    # that there are nodes that have the flag and their deprel is 'conj'.
    # Of course that is not a proof that it happens always when it should.)
    # In that case, the parent is the first conjunct, and the effective parent
    # lies one or more levels further up. However, we solve this in the
    # function add_enhanced_parent_of_coordination(). Therefore, we do nothing
    # for non-first conjuncts in coordinate shared dependents here.
    if($node->is_shared_modifier())
    {
        # Get all suitable incoming enhanced relations.
        my @iedges = grep {$_->[1] !~ m/^(conj|cc|punct)(:|$)/} ($self->get_enhanced_deps($node));
        foreach my $iedge (@iedges)
        {
            my $parent = $self->get_node_by_ord($node, $iedge->[0]);
            my $edeprel = $iedge->[1];
            my @conjuncts = $self->recursively_collect_conjuncts($parent);
            foreach my $conjunct (@conjuncts)
            {
                $self->add_enhanced_dependency($node, $conjunct, $edeprel);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Returns the list of conj children of a given node. If there is nested
# coordination, returns the nested conjuncts too.
#------------------------------------------------------------------------------
sub recursively_collect_conjuncts
{
    my $self = shift;
    my $node = shift;
    my $visited = shift;
    # Keep track of visited nodes. Avoid endless loops.
    my @_dummy;
    if(!defined($visited))
    {
        $visited = \@_dummy;
    }
    return () if($visited->[$node->ord()]);
    $visited->[$node->ord()]++;
    my @echildren = $self->get_enhanced_children($node);
    my @conjuncts = grep {my $x = $_; any {$_->[0] == $node->ord() && $_->[1] =~ m/^conj(:|$)/} ($self->get_enhanced_deps($x))} (@echildren);
    my @conjuncts2;
    foreach my $c (@conjuncts)
    {
        my @c2 = $self->recursively_collect_conjuncts($c, $visited);
        if(scalar(@c2) > 0)
        {
            push(@conjuncts2, @c2);
        }
    }
    return (@conjuncts, @conjuncts2);
}



#------------------------------------------------------------------------------
# Looks for an external, grammatically coreferential subject of an open clausal
# complement (xcomp). Adds a subject relation if it finds it.
#
# Interactions with propagation of dependencies across coordination:
# If we do external subjects after coordination:
# * if the source argument for the subject is coordination (as in "John and
#   Mary wanted to do it"), by now we have a separate nsubj relation to each of
#   the conjuncts, and we can copy each of them as an xsubj.
# * if the control verb is coordination with a shared subject (as in "John
#   promised and succeeded to do it"), nothing new happens because we have the
#   xsubj relation from "do" to "John" anyway. However, if the conjuncts share
#   the xcomp but not the subject (as in "John promised and Mary succeeded to
#   do it"), we can now draw an xsubj from "do" to both "John" and "Mary".
# * if the controlled complement is coordination (as in "John promised to come
#   and clean up"), we can draw an xsubj from each of them.
# If we do external subjects before coordination:
# * an xsubj shared among coordinate xcomps could still be multiplied but only
#   if we mark it as a shared dependent when drawing the first xsubj.
# * coordinate control verbs with private control arguments will not propagate
# * coordinate control arguments will propagate via shared parent.
#
# Interactions with transformation of relative clauses:
# * žák, kterého chci přinutit naučit se počítat
#   (student whom I want to force to learn how to calculate)
# If we do relative clauses first
# * the controlled verb can point directly to the modified noun instead of the
#   relative pronoun. But it will not see that the relative pronoun was in the
#   accusative, hence it will not recognize the noun (which is in nominative)
#   as a suitable controller.
# If we do external subjects first
# * the xcomp infinitive will have the relative pronoun as its nsubj:xsubj.
#   A copy of this relation will be drawn to the noun, regardless of that the
#   parent is not the root of the relative clause.
#------------------------------------------------------------------------------
sub add_enhanced_external_subject
{
    my $self = shift;
    my $node = shift;
    my $visited = shift; # to avoid processing the same verb twice if we need to look at it early
    return if($visited->[$node->ord()]);
    $visited->[$node->ord()]++;
    # Are there any incoming xcomp edges?
    my @gverbs = $self->get_enhanced_parents($node, '^xcomp(:|$)');
    return if(scalar(@gverbs) == 0);
    # The governing verb may itself be an infinitive controlled by another verb.
    # Make sure it is processed before myself, otherwise we may not be able to
    # reach to its enhanced subject.
    foreach my $gv (@gverbs)
    {
        $self->add_enhanced_external_subject($gv, $visited);
    }
    ###!!! This part is language-dependent, hence it should be moved to a
    ###!!! language-specific block!
    my @nomcontrol = ();
    my @datcontrol = ();
    my @acccontrol = ();
    if($self->language() eq 'cs')
    {
        # Czech verbs whose subject can control an open complement (infinitive).
        @nomcontrol =
        (
            # Modality / external circumstances:
            qw(moci mít muset musit smět potřebovat),
            # Modality / will of the actor:
            # Weak positive:
            qw(chtít hodlat mínit plánovat zamýšlet toužit troufnout troufat odvážit odvažovat odhodlat odhodlávat zvyknout zvykat),
            # Strong positive:
            qw(rozhodnout rozhodovat zavázat zavazovat přislíbit slíbit slibovat),
            # Strong negative:
            qw(odmítnout odmítat),
            # Weak negative:
            qw(bát obávat stydět zdráhat ostýchat rozmyslit rozpakovat váhat),
            # Passive negative:
            qw(zapomenout zapomínat opomenout opomíjet),
            # Ability:
            qw(umět dokázat dovést snažit namáhat usilovat pokusit pokoušet zkusit zkoušet stačit stihnout stíhat zvládnout zvládat),
            # Aspect and phase:
            qw(chystat začít začínat jmout počít počínat zůstat vydržet přestat přestávat končit skončit),
            # Movement (to go somewhere to do something):
            qw(jít chodit utíkat spěchat jet jezdit odejít odcházet odjet odjíždět přijít přicházet přijet přijíždět),
            # Other action than movement:
            qw(vzít),
            # Attitude of the speaker:
            qw(zdát hrozit ráčit),
            # Pseudocopulas: (not "znamenat", there is no coreference!)
            qw(působit pracovat cítit ukazovat ukázat)
        );
        # Czech verbs whose dative argument can control an open complement (infinitive).
        @datcontrol =
        (
            # Enabling:
            qw(umožnit umožňovat dovolit dovolovat povolit povolovat dát dávat příslušet),
            # Recommendation:
            qw(doporučit doporučovat navrhnout navrhovat poradit radit),
            # Order:
            qw(uložit ukládat přikázat přikazovat nařídit nařizovat velet klást kázat),
            # Negative order, disabling:
            qw(bránit zabránit zabraňovat znemožnit znemožňovat zakázat zakazovat zapovědět zapovídat),
            # Success:
            qw(podařit dařit)
        );
        # Czech verbs whose accusative argument can control an open complement (infinitive).
        @acccontrol =
        (
            # Enabling or request:
            qw(oprávnit opravňovat zmocnit zmocňovat prosit),
            # Order, enforcement:
            qw(donutit přinutit nutit přimět zavázat zavazovat pověřit pověřovat přesvědčit přesvědčovat odsoudit odsuzovat),
            # Teaching:
            qw(učit naučit odnaučit odnaučovat),
            # Seeing (viděl umírat lidi):
            qw(vidět),
            # Pseudocopulas:
            qw(činit učinit)
        );
    }
    elsif($self->language() eq 'sk') #------------------------------------------------------------------------------------------------------------------
    {
        # Slovak verbs whose subject can control an open complement (infinitive).
        @nomcontrol =
        (
            # Modality / external circumstances:
            qw(môcť mať musieť smieť potrebovať),
            # Modality / will of the actor:
            # Weak positive:
            qw(chcieť hodlať mieniť plánovať zamýšľať túžiť trúfnuť trúfať odvážiť odvažovať odhodlať odhodlávať želať),
            # Strong positive:
            qw(rozhodnúť rozhodovať zaviazať zaväzovať prisľúbiť sľúbiť sľubovať),
            # Strong negative:
            qw(odmietnuť odmietať),
            # Weak negative:
            qw(báť obávať hanbiť zdráhať ostýchať rozmyslieť rozpakovať váhať),
            # Passive negative:
            qw(zabudnúť zabúdať opomenúť),
            # Ability:
            qw(vedieť dokázať doviesť snažiť namáhať usilovať pokúsiť pokúšať skúsiť skúšať stačiť stihnúť stíhať zvládnuť vládať),
            # Aspect and phase:
            qw(chystať začať začínať počať počínať zostať ostať vytrvať prestať prestávať končiť skončiť),
            # Movement (to go somewhere to do something):
            qw(ísť chodiť utekať ponáhľať jet jazdiť odísť odchádzať prísť přichádzať),
            # Other action than movement:
            qw(vziať),
            # Attitude of the speaker:
            qw(zdať hroziť ráčiť),
            # Pseudocopulas: (not "znamenať", there is no coreference!)
            qw(pôsobiť pracovať cítiť ukazovať ukázať)
        );
        # Slovak verbs whose dative argument can control an open complement (infinitive).
        @datcontrol =
        (
            # Enabling:
            qw(umožniť umožňovať dovoliť dovoľovať povoliť povoľovať dať dávať prináležať),
            # Recommendation:
            qw(odporučiť odporúčať navrhnúť navrhovať poradiť radiť hovoriť povedať pobádať),
            # Order:
            qw(uložiť ukladať prikázať prikazovať nariadiť nariaďovať veliť klásť kázať),
            # Negative order, disabling:
            qw(brániť zabrániť zabraňovať znemožniť znemožňovať zakázať zakazovať),
            # Success:
            qw(podariť dariť postačiť)
        );
        # Slovak verbs whose accusative argument can control an open complement (infinitive).
        @acccontrol =
        (
            # Enabling or request:
            qw(oprávniť opravňovať zmocniť zmocňovať prosiť poprosiť pustiť),
            # Order, enforcement:
            qw(donútiť prinútiť nútiť zaviazať zaväzovať poveriť poverovať presvedčiť presviedčať odsúdiť odsudzovať),
            # Teaching:
            qw(učiť naučiť odnaučiť odučovať),
            # Seeing (viděl umírat lidi):
            qw(vidieť),
            # Pseudocopulas:
            qw(činiť urobiť)
        );
    }
    elsif($self->language() eq 'pl') #------------------------------------------------------------------------------------------------------------------
    {
        # Polish verbs whose subject can control an open complement (infinitive).
        @nomcontrol =
        (
            # Modality / external circumstances:
            qw(móc można mieć winien powinien musieć potrzebować),
            # Modality / will of the actor:
            # Weak positive:
            qw(chcieć zechcieć zamierzać myśleć pomyśleć planować deliberować woleć pragnąć marzyć śnić śmieć ośmielić odważyć lubić),
            # Strong positive:
            qw(postanowić postanawiać decydować zdecydować obiecać obiecywać ślubować zgodzić),
            # Strong negative:
            #qw(odmietnuť odmietať),
            # Weak negative:
            qw(obawiać),
            # Passive negative:
            qw(zapomnieć omieszkać),
            # Ability:
            qw(umieć wiedzieć potrafić zdążyć zdołać starać postarać usiłować próbować spróbować),
            # Aspect and phase:
            qw(chystať jąć zacząć zaczynać począć poczynać pozostawać przestać przestawać kończyć skończyć powstrzymywać),
            # Movement (to go somewhere to do something):
            qw(iść pójść chodzić jechać przyjść przychodzić wydawać),
            # Other action than movement:
            qw(kłaść),
            # Attitude of the speaker:
            qw(zdawać raczyć),
            # Pseudocopulas: (not "znaczyć", there is no coreference!)
            #qw(pôsobiť pracovať cítiť ukazovať ukázať)
        );
        # Polish verbs whose dative argument can control an open complement (infinitive).
        @datcontrol =
        (
            # Enabling:
            qw(dozwolić dovoľovať pozwolić pozwalać dać dawać należeć pozostawać),
            # Recommendation:
            qw(polecić zalecać proponować radzić),
            # Order:
            qw(rozkazać rozkazować nakazać nakazywać kazać),
            # Negative order, disabling:
            qw(szkodzić przeszkadzać),
            # Success:
            qw(udać udawać zdążyć zdarzać opłacać wypadać)
        );
        # Polish verbs whose accusative argument can control an open complement (infinitive).
        @acccontrol =
        (
            # Enabling or request:
            #qw(oprávniť opravňovať zmocniť zmocňovať prosić poprosiť pustiť),
            # Order, enforcement:
            #qw(donútiť prinútiť nútiť zaviazať zaväzovať poveriť poverovať presvedčiť presviedčať odsúdiť odsudzovať),
            # Teaching:
            qw(uczyć nauczyć),
            # Seeing (viděl umírat lidi):
            qw(widzieć),
            # Pseudocopulas:
            #qw(činiť urobiť)
        );
    }
    elsif($self->language() eq 'ru') #------------------------------------------------------------------------------------------------------------------
    {
        # Russian verbs whose subject can control an open complement (infinitive).
        @nomcontrol =
        (
            # Modality / external circumstances:
            qw(мочь требовать),
            # Modality / will of the actor:
            # Weak positive: (warning: желать can control either nominative or, if present, dative)
            qw(хотеть захотеть планировать намереваться рассчитывать предпочесть предпочитать надеяться думать задумать придумать мечтать счесть сметь любить привыкнуть),
            # Strong positive:
            qw(решить решать решиться решаться собраться обещать пообещать согласиться договориться гарантировать),
            # Strong negative:
            qw(отказаться отказываться),
            # Weak negative:
            qw(бояться),
            # Passive negative:
            qw(забыть забывать),
            # Ability:
            qw(уметь знать успеть успевать пытаться стремиться стараться браться норовить затрудниться пробовать учиться научиться),
            # Aspect and phase:
            qw(собираться готовиться начать начинать приняться продолжить продолжать остаться оставаться уставать перестать переставать прекратить),
            # Movement (to go somewhere to do something):
            qw(пойти идти ездить отправиться спешить торопиться прийти приходить приехать),
            # Other action than movement:
            qw(догадаться),
            # Attitude of the speaker:
            qw(рискнуть рисковать грозить),
            # Pseudocopulas: (not "значить", there is no coreference!)
            qw(стать считать)
        );
        # Tyhle se našly bez předmětu, ale koreference nastane, až když k nim přidáme předmět:
        # позволять позволить вынудить просить предложить хотеться помочь давать предлагать помогать заставлять дать обязать призвать призывать
        # мешать рекомендовать советовать велеть запретить заставить разрешать запрещать разрешить учить
        # Tohle je kiks, nemá být xcomp, ale ccomp: выбирать (vybrat si, co dělat).
        # Russian verbs whose dative argument can control an open complement (infinitive).
        @datcontrol =
        (
            # Enabling:
            qw(разрешить разрешать позволить позволять напозволять дать давать доверить доверять предоставить предоставлять),
            # Modality / will of the actor:
            qw(хотеться захотеться быть прийтись),
            # Recommendation:
            qw(рекомендовать предложить предлагать советовать посоветовать сказать подсказать подсказывать),
            # Order:
            qw(задать задавать приказать приказывать поручить поручать командовать велеть предписать заказать наказать),
            # Negative order, disabling:
            qw(мешать запретить запрещать препятствовать),
            # Success:
            qw(удаться)
        );
        # Russian verbs whose accusative argument can control an open complement (infinitive).
        @acccontrol =
        (
            # Enabling or request:
            qw(просить попросить призвать призывать звать пригласить приглашать заклинать),
            # Order, enforcement, encouragement:
            qw(вынудить вынуждать понуждать принудить принуждать заставить заставлять побудить побуждать поручить поручать убедить убеждать уговаривать обязать обязывать стимулировать вдохновить вдохновлять мотивировать подвинуть поощрять провоцировать тянуть уговорить),
            # Teaching:
            qw(учить научить обучить обучать отучить отучать),
            # Movement (to send somebody somewhere to do something):
            qw(отправить отправлять послать отослать присылать брать),
            # Seeing (viděl umírat lidi):
            qw(видеть),
            # Pseudocopulas:
            #qw(činiť urobiť)
        );
    }
    elsif($self->language() eq 'lt') #------------------------------------------------------------------------------------------------------------------
    {
        # Lithuanian verbs whose subject can control an open complement (infinitive).
        @nomcontrol =
        (
            # Modality / external circumstances:
            qw(galėti turėti reikėti privalėti tekti),
            # Modality / will of the actor:
            # Weak positive:
            qw(siekti norėti norėtis planuoti ketinti numatyti mėgti),
            # Strong positive:
            qw(nuspręsti),
            # Strong negative:
            #qw(odmietnuť odmietať),
            # Weak negative:
            qw(atsisakyti bijoti),
            # Passive negative:
            #qw(zabudnúť zabúdať opomenúť),
            # Ability:
            qw(bandyti pabandyti stengtis mėginti pasistengti sugebėti išmokti mokytis pavykti),
            # Aspect and phase:
            qw(pradėti belikti telikti),
            # Movement (to go somewhere to do something):
            #qw(ísť chodiť utekať ponáhľať jet jazdiť odísť odchádzať prísť přichádzať),
            # Other action than movement:
            qw(imti),
            # Attitude of the speaker:
            qw(rizikuoti),
            # Pseudocopulas: (not "znamenať", there is no coreference!)
            #qw(pôsobiť pracovať cítiť ukazovať ukázať)
        );
        # Lithuanian verbs whose dative argument can control an open complement (infinitive).
        @datcontrol =
        (
            # Enabling:
            qw(leisti),
            # Recommendation:
            qw(siūlyti pasiūlyti patarti raginti rekomenduoti),
            # Order:
            #qw(uložiť ukladať prikázať prikazovať nariadiť nariaďovať veliť klásť kázať),
            # Negative order, disabling:
            #qw(brániť zabrániť zabraňovať znemožniť znemožňovať zakázať zakazovať),
            # Success:
            #qw(podariť dariť postačiť)
        );
        # Lithuanian verbs whose accusative argument can control an open complement (infinitive).
        @acccontrol =
        (
            # Enabling or request:
            qw(prašyti paprašyti),
            # Order, enforcement:
            qw(priversti),
            # Teaching:
            qw(mokyti),
            # Seeing (viděl umírat lidi):
            #qw(vidieť),
            # Pseudocopulas:
            #qw(činiť urobiť)
        );
    }
    elsif($self->language() eq 'fi') #------------------------------------------------------------------------------------------------------------------
    {
        # Finnish verbs whose subject can control an open complement (infinitive).
        # saada = get have make obtain
        # tulla = become come get arrive
        # auttaa = help assist aid
        # antaa = give let issue deliver
        # kannustaa = encourage urge stimulate
        # käydä = visit call go run
        # käyttää = use exercise wear operate
        # pakottaa = force drive compel oblige
        # asettaa = set lay position place
        # estää = prevent preclude forestall inhibit
        # kehittää = develop evolve improve elaborate
        # kehottaa = urge recommend invite advise
        # kieltää = prohibit forbid
        # lähettää = send broadcast post transmit
        # laittaa = put lay set fix
        # olla = be exist have hold
        # pyytää = request ask demand seek
        # sallia = allow permit let tolerate
        # suositella = recommend commend
        # työskennellä = work
        # varoittaa = warn caution dissuade
        @nomcontrol =
        (
            # Modality / external circumstances:
            # pystyä = can
            qw(pystyä),
            # Modality / will of the actor:
            # Weak positive:
            # haluta = want; kiinnostua = be interested in; tarjoutua = offer
            qw(haluta kiinnostua tarjoutua),
            # Strong positive:
            # päättää = decide; luvata = promise; suostua = agree
            qw(päättää luvata suostua),
            # Strong negative:
            # kieltäytyä = refuse
            qw(kieltäytyä),
            # Weak negative:
            # epäröidä = hesitate
            qw(epäröidä),
            # Passive negative:
            #qw(zabudnúť zabúdať opomenúť),
            # Ability:
            # onnistua = succeed; yrittää = try; koettaa = try; pyrkiä = strive;
            # osata = know, master
            qw(onnistua yrittää koettaa pyrkiä osata),
            # Aspect and phase:
            # alkaa = begin; keskittyä = attend, settle down; koittaa = break;
            # päätyä = end up, finish up
            qw(alkaa keskittyä koittaa päätyä),
            # Movement (to go somewhere to do something):
            #qw(ísť chodiť utekať ponáhľať jet jazdiť odísť odchádzať prísť přichádzať),
            # Other action than movement:
            # kiirehtiä = rush; palata = return, revive
            qw(kiirehtiä palata),
            # Attitude of the speaker:
            # viitsiä = bother
            qw(viitsiä),
        );
    }
    elsif($self->language() eq 'et') #------------------------------------------------------------------------------------------------------------------
    {
        # Estonian verbs whose subject can control an open complement (infinitive).
        # aitama = help assist aid
        # soovitama = recommend commend suggest
        # laskma = have let allow
        # paluma = ask pray beg
        # lubama = allow permit let authorize
        # saama = receive become get acquire
        # tegema = do perform make execute
        # võimaldama = enable allow permit
        # andma = give grant yield allow
        # jõudma = reach arrive come get
        # käskima = command order tell
        # keelama = prohibit forbid ban
        # olenema = depend turn
        @nomcontrol =
        (
            # Modality / external circumstances:
            # suutma = can; pruukima = need
            qw(suutma pruukima),
            # Modality / will of the actor:
            # Weak positive:
            # tahtma = want; julgema = dare; soovima = wish; kavatsema = plan;
            # lootma = hope; pakkuma = offer; söandama = dare
            qw(tahtma julgema soovima kavatsema lootma pakkuma söandama),
            # Strong positive:
            # otsustama = decide; võtma = admit
            qw(otsustama võtma),
            # Strong negative:
            # keelduma = refuse
            qw(keelduma),
            # Weak negative:
            # jaksama = endure; kannatama = suffer; kartma = fear; muretsema = worry
            qw(jaksama kannatama kartma muretsema),
            # Passive negative:
            #qw(zabudnúť zabúdať opomenúť),
            # Ability:
            # oskama = know how; püüdma = strive; üritama = try; proovima = try;
            # katsuma = attempt
            qw(oskama püüdma üritama proovima katsuma),
            # Aspect and phase:
            # algama = begin
            qw(algama),
            # Movement (to go somewhere to do something):
            #qw(ísť chodiť utekať ponáhľať jet jazdiť odísť odchádzať prísť přichádzať),
            # Other action than movement:
            # kiirustama = rush
            qw(kiirustama),
            # Attitude of the speaker:
            # viitsima = bother; suvatsema = deign
            qw(viitsima suvatsema),
        );
    }
    foreach my $gv (@gverbs)
    {
        my $lemma = $gv->lemma();
        if(!defined($lemma))
        {
            my $form = $gv->form() // '';
            log_warn("Skipping control verb '$form' because its lemma is undefined.");
            next;
        }
        # Is this a subject-control verb?
        if(any {$_ eq $lemma} (@nomcontrol))
        {
            # Does the control verb have an overt subject?
            my @subjects = $self->get_enhanced_children($gv, '^[nc]subj(:|$)');
            foreach my $subject (@subjects)
            {
                my @edeps = grep {$_->[0] == $gv->ord() && $_->[1] =~ m/^[nc]subj(:|$)/} ($self->get_enhanced_deps($subject));
                if(scalar(@edeps) == 0)
                {
                    # This should not happen, as we explicitly asked for nodes that are in the subject relation.
                    log_fatal("Subject relation disappeared.");
                }
                elsif(scalar(@edeps) > 1)
                {
                    # This should not happen either, although it is not forbidden. But the same two nodes should not be connected simultaneously via nsubj, csubj, and/or nsubj:pass...
                    log_warn("Multiple subject relations between the same two nodes: ".join(', ', map {$_->[1]} (@edeps)));
                }
                my $edeprel = $edeps[0][1];
                # We could now add the ':xsubj' subtype to the relation label.
                # But we would first have to remove the previous subtype, if any.
                # And replacing ':pass' by ':xsubj' would do more harm than good,
                # so we just keep it as it is.
                $self->add_enhanced_dependency($subject, $node, $edeprel);
            }
        }
        # Is this a dative-control verb?
        elsif(any {$_ eq $lemma} (@datcontrol))
        {
            # Does the control verb have an overt dative argument?
            my @objects = $self->get_enhanced_children($gv, '^(i?obj|obl:arg)(:|$)');
            # Select those arguments that are dative nominals without adpositions.
            @objects = grep
            {
                my $x = $_;
                my @casechildren = $self->get_enhanced_children($x, '^case(:|$)');
                $x->is_dative() && scalar(@casechildren) == 0
            }
            (@objects);
            # If there are no dative objects, maybe there are reflexive dative expletives ("si").
            if(scalar(@objects) == 0)
            {
                my @expletives = grep {$_->is_dative() && $_->is_reflexive()} ($self->get_enhanced_children($gv, '^expl(:|$)'));
                if(scalar(@expletives) > 0)
                {
                    # We will not mark coreference with the expletive. It is
                    # reflexive, so we have also a coreference with the subject;
                    # let's look for the subject then.
                    my @subjects = $self->get_enhanced_children($gv, '^[nc]subj(:|$)');
                    @objects = @subjects;
                }
            }
            foreach my $object (@objects)
            {
                # Switch to 'nsubj:pass' if the controlled infinitive is passive.
                # Example: Zákon mu umožňuje být zvolen.
                my $edeprel = 'nsubj';
                if($node->iset()->is_passive() || scalar($self->get_enhanced_children($node, '^(aux|expl):pass(:|$)')) > 0)
                {
                    $edeprel = 'nsubj:pass';
                }
                $self->add_enhanced_dependency($object, $node, $edeprel);
            }
        }
        # Is this an accusative-control verb?
        elsif(any {$_ eq $lemma} (@acccontrol))
        {
            # Does the control verb have an overt accusative argument?
            my @objects = $self->get_enhanced_children($gv, '^(i?obj|obl:arg)(:|$)');
            # Select those arguments that are accusative nominals without adpositions.
            @objects = grep
            {
                my $x = $_;
                my @casechildren = $self->get_enhanced_children($x, '^case(:|$)');
                # In Slavic and some other languages, the case of a quantified phrase may
                # be determined by the quantifier rather than by the quantified head noun.
                # We can recognize such quantifiers by the relation nummod:gov or det:numgov.
                my @qgov = $self->get_enhanced_children($x, '^(nummod:gov|det:numgov)$');
                my $qgov = scalar(@qgov);
                # There is probably just one quantifier. We do not have any special rule
                # for the possibility that there are more than one.
                my $caseiset = $qgov ? $qgov[0]->iset() : $x->iset();
                $caseiset->is_accusative() && scalar(@casechildren) == 0
            }
            (@objects);
            # If there are no accusative objects, maybe there are reflexive accusative expletives ("se").
            if(scalar(@objects) == 0)
            {
                my @expletives = grep {$_->is_accusative() && $_->is_reflexive()} ($self->get_enhanced_children($gv, '^expl(:|$)'));
                if(scalar(@expletives) > 0)
                {
                    # We will not mark coreference with the expletive. It is
                    # reflexive, so we have also a coreference with the subject;
                    # let's look for the subject then.
                    my @subjects = $self->get_enhanced_children($gv, '^[nc]subj(:|$)');
                    @objects = @subjects;
                }
            }
            foreach my $object (@objects)
            {
                # Switch to 'nsubj:pass' if the controlled infinitive is passive.
                # Example: Zákon ho opravňuje být zvolen.
                my $edeprel = 'nsubj';
                if($node->iset()->is_passive() || scalar($self->get_enhanced_children($node, '^(aux|expl):pass(:|$)')) > 0)
                {
                    $edeprel = 'nsubj:pass';
                }
                $self->add_enhanced_dependency($object, $node, $edeprel);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Transforms the enhanced dependencies between a relative clause, its
# relativizer, and the modified noun.
#
# Interactions with propagation of dependencies across coordination:
# If we do relative clauses before coordination:
# * coordinate parent nominals: new incoming (nsubj/obj/...) and outgoing (ref)
#   edges will be later propagated to/from the other conjuncts. We actually
#   do not know whether the relative clause is shared among the conjuncts. If
#   it is, then we should mark the relevant nodes as shared dependents.
# * coordinate relative clauses: the second clause does not know it is a
#   relative clause, so it does nothing.
# If we do relative clauses after coordination:
# * if the relative clause is shared among coordinate parent nominals, by now
#   we have a separate acl:relcl dependency to each of them. And if we actually
#   look at the enhanced graph, we will get all the transformations.
# * coordinate relative clauses: we could transform each of them and the parent
#   nominal could even have a different function in each of them. If they share
#   the relativizer, we could see it as well.
#------------------------------------------------------------------------------
sub add_enhanced_relative_clause
{
    my $self = shift;
    my $node = shift;
    # This node is the root of a relative clause if at least one of its parents
    # is connected via the acl:relcl relation. We refer to the parent of the
    # clause as the modified $noun, although it may be a pronoun.
    my @nouns = $self->get_enhanced_parents($node, '^acl:relcl(:|$)');
    return if(scalar(@nouns)==0);
    # If there are coordinate relative clauses, we may have already added a
    # cycle, meaning that the modified noun is now also a descendant of the
    # relative clause. However, we do not want to traverse it when looking for
    # the relativizer! Hence we mark it as visited before collecting the
    # descendants.
    # Example:
    # máme povědomí, jaké to bude těleso, se kterým by se Země mohla či měla srazit
    # The noun is "těleso", the coordinate relative clauses are headed by
    # "mohla" and "měla", and the unwanted relativizer is "jaké", attached to
    # "těleso" (the correct relativizer is "kterým" and it is shared by both
    # relative clauses).
    my @visited; map {$visited[$_->ord()]++} (@nouns);
    my @relativizers = sort {$a->ord() <=> $b->ord()}
    (
        grep {$_->ord() <= $node->ord() && $_->is_relative()}
        (
            $node,
            $self->get_enhanced_descendants($node, \@visited)
        )
    );
    return unless(scalar(@relativizers) > 0);
    ###!!! Assume that the leftmost relativizer is the one that relates to the
    ###!!! current relative clause. This is an Indo-European bias.
    my $relativizer = $relativizers[0];
    my @edeps = $self->get_enhanced_deps($relativizer);
    # All relations other than 'ref' will be copied to the noun.
    # Besides 'ref', we should also exclude any collapsed paths over empty nodes
    # (unless we can give them the special treatment they need). This is because
    # there may be a second relative clause as a gapped conjunct, and the collapsed
    # edge may lead back to the noun. An instance of this occurs in the Latvian
    # LVTB training data, sent_id = a-p13850-p28s2:
    # "personas, kura nebūtu saistīta ar pārējām un arī ar putnu"
    # "a person which is unrelated to the rest and also to the bird"
    # The first relative clause:
    #   acl:relcl(personas, saistīta)
    #   nsubj(saistīta, kura)
    #   iobj(saistīta, pārējām)
    # The second relative clause uses an empty node with the id 37.1 for a copy of saistīta:
    #   acl>37.1>nsubj(personas, kura)
    #   acl>37.1>iobj(personas, putnu)
    ###!!! We now avoid creating a cycle when processing this Latvian sentence.
    ###!!! But we do not transform the second relative clause correctly.
    ###!!! Either the self-loops should be allowed in such cases, or the entire
    ###!!! mechanism for empty nodes in Treex must be rewritten and real Node
    ###!!! objects must be used.
    my @noundeps = grep {$_->[1] ne 'ref' && $_->[1] !~ m/>/} (@edeps);
    foreach my $noun (@nouns)
    {
        # Add an enhanced relation 'ref' from the modified noun to the relativizer.
        $self->add_enhanced_dependency($relativizer, $noun, 'ref');
        # If the relativizer is the root of the relative clause, there is no other
        # node in the relative clause from which a new relation should go to the
        # modified noun. However, the relative clause has a nominal predicate,
        # which corefers with the modified noun, and we can draw a new relation
        # from the modified noun to the subject of the relative clause.
        if($relativizer == $node)
        {
            my @subjects = grep {$_->deprel() =~ m/^[nc]subj(:|$)/} ($node->children());
            foreach my $subject (@subjects)
            {
                $self->add_enhanced_dependency($subject, $noun, $subject->deprel());
            }
        }
        # If the relativizer is not the root of the relative clause, we remove its
        # current relation to its current parent and instead we add an analogous
        # relation between the parent and the modified noun.
        else
        {
            foreach my $nd (@noundeps)
            {
                my $relparent = $nd->[0];
                my $reldeprel = $nd->[1];
                # Although the the current node (root of the relative clause)
                # is not the relativizer, the possibility of self-loops is not
                # excluded. In the Finnish TDT training sentence f102.5, there
                # is coordination of relative clauses, the first clause is
                # headed by the relativizer, which at the same time acts as
                # an oblique argument in the second and the third clause. When
                # we process it from the perspective of the second clause (where it is not the root),
                # we will also see the acl:relcl relation that connects it to
                # the modified noun. We must ignore this relation, otherwise it
                # will lead to a self-loop.
                # Niitä, joilla on farmariautot sekä kultainennoutaja kopissaan, lapset huutavat ja kiirettä tuntuu olevan kokoajan arjen keskellä.
                # Google Translate: Children with station wagons and a golden retriever in their booths are screaming and hurrying in the midst of everyday life.
                # Niitä = those (partitive demonstrative) is the root of the sentence.
                # First clause: joilla on farmariautot sekä kultainennoutaja kopissaan = with station wagons and a golden retriever in their booth (joilla = whose = the head and the relativizer)
                # Second clause: lapset huutavat = the children cry (joilla is oblique argument of this)
                # Third clause: ja kiirettä tuntuu olevan kokoajan arjen keskellä (joilla oblique here too) = and hurry seems to be in the middle of everyday life
                # I.e.: those, whose are station wagons, whose children cry and who feel in a hurry
                my $relparentnode = $self->get_node_by_ord($node, $relparent);
                next if($relparentnode == $noun);
                # Even if the relativizer is adverb or determiner, the new dependent will be noun or pronoun.
                # Discard subtypes of the original relation, if present. Such subtypes may not be available
                # for the substitute relation.
                $reldeprel =~ s/^advmod(:.+)?$/obl/;
                $reldeprel =~ s/^det(:.+)?$/nmod/;
                $self->add_enhanced_dependency($noun, $relparentnode, $reldeprel);
            }
        }
    }
    # We have to wait with removing the non-ref relations until all relative
    # clauses in the sentence have been processed, so it will be done in a
    # separate function.
}



#------------------------------------------------------------------------------
# Removes non-ref incoming edges of all relativizers except those that are
# heads of their relative clauses. We must do this after all edges from all
# relative clauses to their nouns have been added. If we do this earlier and
# if a relativizer is shared among coordinate relative clauses (or coordinate
# modified nouns), we will not be able to find the relativizer from the other
# relative clauses.
#------------------------------------------------------------------------------
sub remove_enhanced_non_ref_relations
{
    my $self = shift;
    my $node = shift;
    # Only do this to relativizers. Every relativizer has at least one incoming
    # ref edge by now.
    my @edeps = $self->get_enhanced_deps($node);
    return if(!any {$_->[1] =~ m/^ref(:|$)/} (@edeps));
    # Do not do this to relativizers that are heads of their relative clauses,
    # i.e., they also have an acl:relcl incoming edge.
    return if(any {$_->[1] =~ m/^acl:relcl(:|$)/} (@edeps));
    my @reldeps = grep {$_->[1] =~ m/^ref(:|$)/} (@edeps);
    $node->wild()->{enhanced} = \@reldeps;
}



#------------------------------------------------------------------------------
# Transforms gapping constructions to structures with empty nodes. The a-layer
# in Treex does not really support empty nodes so we will model them using
# concatenations of incoming and outgoing edges. For example, suppose that
# an empty node should have position 5.1, that it has one conj parent X, one
# nsubj child Y and one obj child Z. Then we will draw an edge from X to Y and
# label it "conj>5.1>nsubj", and an edge from X to Z labeled "conj>5.1>obj".
# We will assume that the block Write::CoNLLU is able to use this information
# to produce the desired CoNLL-U representation of the graph with empty nodes.
#------------------------------------------------------------------------------
sub add_enhanced_empty_node
{
    my $self = shift;
    my $node = shift;
    my $emptynodes = shift; # hash ref, keys are ids of empty nodes
    # We have to generate an empty node if a node has one or more orphan children.
    my @orphans = $self->get_enhanced_children($node, '^orphan(:|$)');
    return if(scalar(@orphans) == 0);
    my $emppos = $self->get_empty_node_position($node, $emptynodes);
    $emptynodes->{$emppos}++;
    # All current parents of $node will become parents of the empty node.
    ###!!! There should not be any 'orphan' among the relations to the parents.
    ###!!! If there is one, we should process the parent first. However, for now
    ###!!! we simply ignore the 'orphan' and change it to 'dep'.
    my @origiedges = $self->get_enhanced_deps($node);
    foreach my $ie (@origiedges)
    {
        $ie->[1] =~ s/^orphan(:|$)/dep$1/;
    }
    # Create the paths to $node via the empty node. We do not know what the
    # relation between the empty node and $node should be. We just use 'dep'
    # for now, unless the node is an adverb, when it is probably safe to say
    # that it is 'advmod'.
    my %nodeiedges;
    my $cdeprel = $node->is_adverb() ? 'advmod' : 'dep';
    foreach my $ie (@origiedges)
    {
        $nodeiedges{$ie->[0]}{$ie->[1].">$emppos>".$cdeprel}++;
    }
    my @nodeiedges;
    foreach my $pord (sort {$a <=> $b} (keys(%nodeiedges)))
    {
        foreach my $edeprel (sort {$a cmp $b} (keys(%{$nodeiedges{$pord}})))
        {
            push(@nodeiedges, [$pord, $edeprel]);
        }
    }
    $node->wild()->{enhanced} = \@nodeiedges;
    # Create the path to each child via the empty node. Also use just 'dep' for
    # now, unless the node is an adverb, when it is probably safe to say
    # that it is 'advmod'.
    my @children = $self->get_enhanced_children($node);
    foreach my $child (@children)
    {
        my @origchildiedges = $self->get_enhanced_deps($child);
        my %childiedges;
        my $ccdeprel = $child->is_adverb() ? 'advmod' : 'dep';
        foreach my $cie (@origchildiedges)
        {
            if($cie->[0] == $node->ord())
            {
                foreach my $pie (@origiedges)
                {
                    my $cdeprel = $cie->[1];
                    # Only redirect selected relations via the empty node:
                    # orphan, cc, mark, punct. Keep the others (in particular
                    # nominal modifiers) attached directly to $node.
                    if($cdeprel =~ m/^(orphan|cc|mark|punct)(:|$)/)
                    {
                        $cdeprel =~ s/^orphan(:.+)?$/$ccdeprel/;
                        $childiedges{$pie->[0]}{$pie->[1].">$emppos>".$cdeprel}++;
                    }
                    else
                    {
                        $childiedges{$cie->[0]}{$cie->[1]}++;
                    }
                }
            }
            else
            {
                $childiedges{$cie->[0]}{$cie->[1]}++;
            }
        }
        my @childiedges;
        foreach my $pord (sort {$a <=> $b} (keys(%childiedges)))
        {
            foreach my $edeprel (sort {$a cmp $b} (keys(%{$childiedges{$pord}})))
            {
                push(@childiedges, [$pord, $edeprel]);
            }
        }
        $child->wild()->{enhanced} = \@childiedges;
    }
}



#------------------------------------------------------------------------------
# Determines position for a new empty node.
# For the moment we will position the empty node right before its first child.
# Exception: if this is a non-first conjunct and the first child is shared
# and appears before the first conjunct, skip it. We do not want to place the
# second conjunct before the first one (conj relation must go left-to-right).
# There might be better heuristics but the position does not matter much.
# However, we must not pick a position that is already taken by another
# empty node. For that we need the hash of all empty nodes generated in this
# sentence so far.
#------------------------------------------------------------------------------
sub get_empty_node_position
{
    my $self = shift;
    my $node = shift; # node to be replaced by the empty node and to become a child of the empty node
    my $emptynodes = shift; # hash ref, keys are ids of existing empty nodes
    # The current node and all its current children will become children of the
    # empty node.
    my @children = $self->get_enhanced_children($node);
    my @empchildren = sort {$a->ord() <=> $b->ord()} ($node, @children);
    my $posmajor = $empchildren[0]->ord() - 1;
    my $posminor = 1;
    # If the current node is a conj child of another node, discard children that
    # occur before that other node.
    my @conjparents = sort {$a->ord() <=> $b->ord()} ($self->get_enhanced_parents($node, '^conj(:|$)'));
    if(scalar(@conjparents) > 0)
    {
        @empchildren = grep {$_->ord() > $conjparents[-1]->ord()} (@empchildren);
        if(scalar(@empchildren) > 0)
        {
            $posmajor = $empchildren[0]->ord() - 1;
        }
        # The else branch should not be needed because at least $node should be
        # located after all its conj parents. But there is no guarantee that the
        # basic annotation is correct.
        else
        {
            $posmajor = $conjparents[-1]->ord();
        }
    }
    while(exists($emptynodes->{"$posmajor.$posminor"}))
    {
        $posminor++;
    }
    my $emppos = "$posmajor.$posminor";
    return $emppos;
}



#==============================================================================
# Helper functions for manipulation of the enhanced graph.
#==============================================================================



#------------------------------------------------------------------------------
# Returns the list of incoming enhanced edges for a node. Each element of the
# list is a pair: 1. ord of the parent node; 2. relation label.
#------------------------------------------------------------------------------
sub get_enhanced_deps
{
    my $self = shift;
    my $node = shift;
    my $wild = $node->wild();
    if(!exists($wild->{enhanced}) || !defined($wild->{enhanced}) || ref($wild->{enhanced}) ne 'ARRAY')
    {
        log_fatal("Wild attribute 'enhanced' does not exist or is not an array reference.");
    }
    return @{$wild->{enhanced}};
}



#------------------------------------------------------------------------------
# Adds a new enhanced edge incoming to a node, unless the same relation with
# the same parent already exists.
#------------------------------------------------------------------------------
sub add_enhanced_dependency
{
    my $self = shift;
    my $child = shift;
    my $parent = shift;
    my $deprel = shift;
    # Self-loops are not allowed in enhanced dependencies.
    # We could silently ignore the call but there is probably something wrong
    # at the caller's side, so we will throw an exception.
    if($parent == $child)
    {
        my $ord = $child->ord();
        my $form = $child->form() // '';
        log_fatal("Self-loops are not allowed in the enhanced graph but we are attempting to attach the node no. $ord ('$form') to itself.");
    }
    my $pord = $parent->ord();
    my @edeps = $self->get_enhanced_deps($child);
    unless(any {$_->[0] == $pord && $_->[1] eq $deprel} (@edeps))
    {
        push(@{$child->wild()->{enhanced}}, [$pord, $deprel]);
    }
}



#------------------------------------------------------------------------------
# Finds a node with a given ord in the same tree. This is useful if we are
# looking at the list of incoming enhanced edges and need to actually access
# one of the parents listed there by ord. We assume that if the method is
# called, the caller is confident that the node should exist. The method will
# throw an exception if there is no node or multiple nodes with the given ord.
#------------------------------------------------------------------------------
sub get_node_by_ord
{
    my $self = shift;
    my $node = shift; # some node in the same tree
    my $ord = shift;
    return $node->get_root() if($ord == 0);
    my @results = grep {$_->ord() == $ord} ($node->get_root()->get_descendants());
    if(scalar(@results) == 0)
    {
        log_fatal("No node with ord '$ord' found.");
    }
    if(scalar(@results) > 1)
    {
        log_fatal("There are multiple nodes with ord '$ord'.");
    }
    return $results[0];
}



#------------------------------------------------------------------------------
# Returns the list of parents of a node in the enhanced graph, i.e., the list
# of nodes from which there is at least one edge incoming to the given node.
# The list is ordered by their ord value.
#
# Optionally the parents will be filtered by regex on relation type.
#------------------------------------------------------------------------------
sub get_enhanced_parents
{
    my $self = shift;
    my $node = shift;
    my $relregex = shift;
    my $negate = shift; # return parents that do not match $relregex
    my @edeps = $self->get_enhanced_deps($node);
    if(defined($relregex))
    {
        if($negate)
        {
            @edeps = grep {$_->[1] !~ m/$relregex/} (@edeps);
        }
        else
        {
            @edeps = grep {$_->[1] =~ m/$relregex/} (@edeps);
        }
    }
    # Remove duplicates.
    my %epmap; map {$epmap{$_->[0]}++} (@edeps);
    my @parents = sort {$a->ord() <=> $b->ord()} (map {$self->get_node_by_ord($node, $_)} (keys(%epmap)));
    return @parents;
}



#------------------------------------------------------------------------------
# Returns the list of children of a node in the enhanced graph, i.e., the list
# of nodes that have at least one incoming edge from the given start node.
# The list is ordered by their ord value.
#
# Optionally the children will be filtered by regex on relation type.
#------------------------------------------------------------------------------
sub get_enhanced_children
{
    my $self = shift;
    my $node = shift;
    my $relregex = shift;
    my $negate = shift; # return children that do not match $relregex
    # We do not maintain an up-to-date list of outgoing enhanced edges, only
    # the incoming ones. Therefore we must search all nodes of the sentence.
    my @nodes = $node->get_root()->get_descendants({'ordered' => 1});
    my @children;
    foreach my $n (@nodes)
    {
        my @edeps = $self->get_enhanced_deps($n);
        if(defined($relregex))
        {
            if($negate)
            {
                @edeps = grep {$_->[1] !~ m/$relregex/} (@edeps);
            }
            else
            {
                @edeps = grep {$_->[1] =~ m/$relregex/} (@edeps);
            }
        }
        if(any {$_->[0] == $node->ord()} (@edeps))
        {
            push(@children, $n);
        }
    }
    # Remove duplicates.
    my %ecmap; map {$ecmap{$_->ord()} = $_ unless(exists($ecmap{$_->ord()}))} (@children);
    @children = map {$ecmap{$_}} (sort {$a <=> $b} (keys(%ecmap)));
    return @children;
}



#------------------------------------------------------------------------------
# Returns the list of nodes to which there is a path from the current node in
# the enhanced graph.
#------------------------------------------------------------------------------
sub get_enhanced_descendants
{
    my $self = shift;
    my $node = shift;
    my $visited = shift;
    # Keep track of visited nodes. Avoid endless loops.
    my @_dummy;
    if(!defined($visited))
    {
        $visited = \@_dummy;
    }
    return () if($visited->[$node->ord()]);
    $visited->[$node->ord()]++;
    my @echildren = $self->get_enhanced_children($node);
    my @echildren2;
    foreach my $ec (@echildren)
    {
        my @ec2 = $self->get_enhanced_descendants($ec, $visited);
        if(scalar(@ec2) > 0)
        {
            push(@echildren2, @ec2);
        }
    }
    # Unlike the method Node::get_descendants(), we currently do not support
    # the parameters add_self, ordered, preceding_only etc. The caller has
    # to take care of sort and grep themselves. (We could do sorting but it
    # would be inefficient to do it in each step of the recursion. And in any
    # case we would not know whether to add self or not; if yes, then the
    # sorting would have to be repeated again.)
    #my @result = sort {$a->ord() <=> $b->ord()} (@echildren, @echildren2);
    my @result = (@echildren, @echildren2);
    return @result;
}



#------------------------------------------------------------------------------
# Returns the relation from a node to parent with ord N. Returns the first
# relation if there are multiple relations to the same parent (this method is
# intended only for situations where we are confident that there is exactly one
# such relation). Throws an exception if the wild attribute 'enhanced' does not
# exist or if there is no relation to the given parent.
#------------------------------------------------------------------------------
sub get_first_edeprel_to_parent_n
{
    my $self = shift;
    my $node = shift;
    my $parentord = shift;
    my @edeps = $self->get_enhanced_deps($node);
    my @edges_from_n = grep {$_->[0] == $parentord} (@edeps);
    if(scalar(@edges_from_n) == 0)
    {
        log_fatal("No relation to parent with ord '$parentord' found.");
    }
    return $edges_from_n[0][1];
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::AddEnhancedUD

=head1 DESCRIPTION

In Universal Dependencies, there is basic and enhanced representation. The
basic representation is a tree and corresponds to the a-tree in Treex. The
enhanced representation is a directed graph and can be optionally stored in
wild attributes of individual nodes (there is currently no API for the
enhanced structure).

This block adds the enhancements defined in the UD v2 guidelines based on the
basic dependencies. The block must be called after the basic dependencies have
been copied to the enhanced graph (see the block CopyBasicToEnhancedUD). It is
important because here we access multiple nodes from one process_node() method
and we need to be sure that all the other nodes already have their enhanced
attribute.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018, 2019 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

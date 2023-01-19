package Treex::Block::T2A::GenerateEmptyNodes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_zone
{
    my $self = shift;
    my $zone = shift;
    # Side effect: Note in the CoNLL-U sentence-level comments that t-layer was available for this sentence.
    ###!!! Maybe this should be done in a separate block, as it is an independent piece of information.
    my $bwild = $zone->get_bundle()->wild();
    my $comment = $bwild->{comment};
    my @comment;
    if ($comment)
    {
        chomp($comment);
        @comment = split(/\n/, $comment);
    }
    push(@comment, 'Tectogrammatical annotation available.');
    $bwild->{comment} = join("\n", @comment)."\n";
    my $troot = $zone->get_tree('t');
    my $aroot = $zone->get_tree('a');
    my @tnodes = $troot->get_descendants({ordered => 1});
    my @anodes = $aroot->get_descendants({ordered => 1});
    my $lastanode = $anodes[-1];
    my $major = 0;
    # Remember the last used minor number for each major number (each anode's ord and zero).
    my @lastminor = (0);
    foreach my $anode (@anodes)
    {
        $lastminor[$anode->ord()] = 0;
    }
    foreach my $tnode (@tnodes)
    {
        my $functor = $tnode->functor() // 'Unknown';
        if($functor eq 'ACT' && $self->tnode_depends_on_copula($tnode))
        {
            $functor .= '.cop';
        }
        if($tnode->is_generated())
        {
            my $anode = $aroot->create_child();
            $anode->set_deprel('dep:empty');
            # Make sure we can access the t-node from the new a-node and vice versa.
            $anode->wild()->{'tnode.rf'} = $tnode->id();
            $tnode->wild()->{'anode.rf'} = $anode->id();
            $anode->wild()->{enhanced} = [];
            $anode->shift_after_node($lastanode);
            $lastanode = $anode;
            my $tlemma = $tnode->t_lemma();
            $anode->set_lemma($tlemma);
            # Store the functor in MISC. It may be useful to understand why the empty node is there.
            $anode->set_misc_attr('Functor', $functor);
            my ($tparent, $aparent) = $self->get_parent($tnode);
            # Guess and set morphology first. It may improve our chances of guessing the correct deprel.
            # If the generated node is a copy of a real node, we may be able to
            # copy its attributes.
            my $source_anode = $tnode->get_lex_anode();
            if(defined($source_anode))
            {
                $anode->set_form($source_anode->form());
                $anode->set_tag($source_anode->tag());
                $anode->set_conll_pos($source_anode->conll_pos()); # XPOS
                $anode->iset()->set_hash($source_anode->iset()->get_hash());
                # The original node may have a wrong case.
                my $source_case = $source_anode->iset()->case();
                if($source_case ne '')
                {
                    my $target_case = $self->guess_case($anode, $aparent, $tparent, $functor);
                    if($target_case ne $source_case)
                    {
                        $target_case = 'gen' if($target_case eq 'abl');
                        $target_case = 'acc' if($target_case eq 'ben');
                        $anode->iset()->set_case($target_case);
                        # The copied word form is wrong (unless there is case syncretism).
                        # Use parentheses to signal that the form cannot be trusted.
                        $anode->set_form('('.$anode->form().')');
                    }
                }
            }
            # The generated node is not a copy of a real node.
            else
            {
                $self->guess_and_set_morphology($anode, $tlemma, $tparent, $functor, $aparent);
            }
            # We need an enhanced relation to make the empty node connected with
            # the enhanced dependency graph. Try to propagate the dependency from
            # the t-tree. (The parent may also help us estimate features of the
            # generated node, such as person of #PersPron. Note however that some
            # of the features may also be available as grammatemes.)
            my $deprel = 'dep';
            # The $aparent may not exist or it may be in another sentence, in
            # which case we cannot use it.
            if(defined($aparent) && $aparent->get_root() == $aroot)
            {
                if(defined($functor))
                {
                    $deprel = $self->guess_deprel($aparent, $anode, $functor);
                }
            }
            # Without connecting the empty node at least to the root, it would not
            # be printed and the graph would not be valid.
            ###!!! It may be possible to attach the node to another empty node.
            ###!!! We would have to generate all nodes first, then to connect them.
            ###!!! However, at present we generate all empty nodes as leaves.
            else
            {
                $aparent = $aroot;
                $deprel = 'root';
            }
            $anode->add_enhanced_dependency($aparent, $deprel);
            # Find a position for the empty node between real nodes.
            $self->position_empty_node($anode, $aparent, $major, \@lastminor);
            # Extra adjustments for generated nodes that are copies of conjuncts in coordination.
            $self->adjust_copied_conjunct($anode, $tnode);
        }
        else # t-node is not generated
        {
            # Remember the ord of the a-node corresponding to the last non-generated
            # t-node. We will use it as the major number for approximate placement of
            # subsequent generated nodes.
            my $anode = $tnode->get_lex_anode();
            # Lexical a-node of a non-generated t-node should be in the same sentence
            # but check it anyway.
            if(defined($anode) and $anode->get_root() == $aroot)
            {
                $major = $anode->ord();
                # Since we store functors at the empty nodes above, store them
                # with normal nodes, too, so they are available everywhere in
                # UD. This is a nasty side effect, it would be better to have
                # a separate block for functors.
                $anode->set_misc_attr('Functor', $functor);
            }
        }
    }
    $aroot->_normalize_ords_and_conllu_ids();
}



#------------------------------------------------------------------------------
# Guesses UPOS, morphological features and form based on tectogrammatical
# lemma and functor (and language).
#------------------------------------------------------------------------------
sub guess_and_set_morphology
{
    my $self = shift;
    my $anode = shift;
    my $tlemma = shift;
    my $tparent = shift;
    my $functor = shift;
    my $aparent = shift;
    my $language = $self->language();
    $anode->set_form('_');
    # https://ufal.mff.cuni.cz/~hajic/2018/docs/PDT20-t-man-cz.pdf
    # AsMuch ... míra okolnosti řídícího děje, v jejímž důsledku nastane nějaký účinek (7.7 Konstrukce se závislou klauzí účinkovou)
    # Benef ... benefaktor v konstrukcích s kontrolou (8.2.4 Kontrola)
    # Cor ... povrchově nevyjádřitelný kontrolovaný člen (8.2.4 Kontrola)
    # EmpNoun ... nepřítomný člen řídící syntaktická adjektiva (5.12.1.2.2 Gramatická elipsa řídícího substantiva)
    # EmpVerb ... nepřítomný řídící predikát slovesných klauzí (5.12.1.1.2 Gramatická elipsa řídícího slovesa)
    # Equal ... nepřítomný pozitiv v konstrukcích se srovnáním (7.4 Konstrukce s významem srovnání)
    # Forn ... nepřítomný řídící uzel cizojazyčného výrazu (7.9 Cizojazyčné výrazy)
    # Gen ... všeobecný aktant (5.2.4.1 Všeobecný aktant a blíže nespecifikovaný aktor)
    # Idph ... pomocný uzel pro zachycení identifikačních výrazů (7.8 Identifikační výrazy)
    # Neg ... pomocný uzel pro zachycení syntaktické negace vyjádřené morfematicky (7.13 Negační a afirmační výrazy)
    # Oblfm ... nepřítomné obligatorní volné doplnění (5.12.2.1.3 Elipsa obligatorního volného doplnění)
    # PersPron ... osobní nebo přivlastňovací zájmeno, může a nemusí být přítomno na povrchu (pokud není, jde o aktuální elipsu) (5.12.2.1.1 Aktuální elipsa obligatorního aktantu)
    # QCor ... povrchově nevyjádřitelné valenční doplnění v konstrukcích s kvazikontrolou (8.2.5 Kvazikontrola)
    # Rcp ... valenční doplnění, které na povrchu není vyjádřeno z důvodu reciprokalizace (5.2.4.2 Reciprocita)
    # Separ ... pomocný uzel pro zachycení souřadnosti, nemá protějšek na povrchu (5.6.1 Zachycení souřadnosti v tektogramatickém stromu)
    # Some ... nepřítomná jmenná část verbonominálního predikátu, zejména ve srovnávacích konstrukcích (7.4 Konstrukce s významem srovnání)
    # Total ... nepřítomný totalizátor v konstrukcích vyjadřujících způsob uvedením výjimky (7.6 Konstrukce s významem omezení a výjimečného slučování)
    # Unsp ... nepřítomné blíže nespecifikované valenční doplnění (5.2.4.1 Všeobecný aktant a blíže nespecifikovaný aktor)
    if($tlemma =~ m/^\#(Q?Cor|Rcp|Oblfm|Benef)$/)
    {
        $anode->set_tag('PRON');
        $anode->iset()->set_hash({'pos' => 'noun', 'prontype' => 'prs'});
    }
    elsif($tlemma eq '#PersPron')
    {
        $anode->set_tag('PRON');
        # Do not use set_hash() because it would reset the features that we may have set above based on the verb.
        my $iset = $anode->iset();
        $iset->set('pos' => 'noun');
        $iset->set('prontype' => 'prs');
        $self->set_personal_pronoun_form($anode, $aparent, $tparent, $functor) if($language eq 'cs');
    }
    elsif($tlemma eq '#Gen')
    {
        $anode->set_tag('PRON');
        $anode->iset()->set_hash({'pos' => 'noun', 'prontype' => 'ind'});
        $self->set_indefinite_pronoun_form($anode, $aparent, $tparent, $functor) if($language eq 'cs');
    }
    # Unlike #Gen, the functor of #Unsp is always ACT and the verb is in third
    # person plural, so 'oni' is better than 'někdo'.
    elsif($tlemma eq '#Unsp')
    {
        $anode->set_tag('PRON');
        $anode->iset()->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'person' => '3', 'number' => 'plur', 'gender' => 'masc', 'animacy' => 'anim', 'case' => 'nom'});
        $anode->set_form('oni') if($language eq 'cs');
    }
    elsif($tlemma eq '#Neg')
    {
        $anode->set_tag('PART');
        $anode->iset()->set_hash({'pos' => 'part', 'polarity' => 'neg'});
        $anode->set_form('ne') if($language eq 'cs');
    }
    # Empty verb that cannot be copied from an overt node but it has overt dependents.
    # Example: "jak [je] vidno" (missing "je"; the other two words should depend on it in the Prague style).
    elsif($tlemma eq '#EmpVerb')
    {
        $anode->set_tag('VERB');
        $anode->iset()->set_hash({'pos' => 'verb'});
    }
    # Empty noun that cannot be copied from an overt node but it has overt dependents.
    # Example: "příliš [peněz] prodělává" (missing "peněz"; it should be a child of "prodělává" and the parent of "příliš").
    # Elided identification expressions ('#Idph') typically also correspond to nominals.
    # Example: "Bydlíme [v ulici] Mezi Zahrádkami 21".
    elsif($tlemma =~ m/^\#(EmpNoun|Idph)$/)
    {
        $anode->set_tag('NOUN');
        $anode->iset()->set_hash({'pos' => 'noun', 'nountype' => 'com'});
    }
    # Elided adverbial expression corresponding to as little / as much / as well...
    # Example: Opravil nám televizor [tak špatně], že za dva dny nefungoval.
    # Example: Zpívali [tak moc], až se hory zelenaly.
    elsif($tlemma eq '#AsMuch')
    {
        $anode->set_form('tak') if($language eq 'cs');
        $anode->set_tag('ADV');
        $anode->iset()->set_hash({'pos' => 'adv'});
    }
    # Elided positive in comparison.
    # Example: Udělal to [stejně], jako to udělal Tonda.
    # Example: Poslanec je [stejný] člověk jako [je] každý jiný [člověk].
    elsif($tlemma eq '#Equal')
    {
        $anode->set_form('stejný/stejně') if($language eq 'cs');
        # We do not know whether it should be ADJ or ADV, so we go by X.
        $anode->set_tag('X');
    }
    # #Some
    # Example: Je stejný jako já [jsem nějaký]. (We cannot copy "stejný" here, so we generate '#Some'.)
    elsif($tlemma eq '#Some')
    {
        $anode->set_form('nějaký') if($language eq 'cs');
        $anode->set_tag('ADJ');
        $anode->iset()->set_hash({'pos' => 'adj'});
    }
    # Missing totalizer '#Total'.
    # Example: Mimo datum se píší [všechny] řadové číslice slovy.
    # Example: Kromě Jihočeské keramiky nepatří tyto firmy mezi nejsilnější. (annotated as "firmy [všechny] kromě Jihočeské keramiky")
    elsif($tlemma eq '#Total')
    {
        $anode->set_form('všichni') if($language eq 'cs');
        $anode->set_tag('DET');
        $anode->iset()->set_hash({'pos' => 'adj', 'prontype' => 'tot'});
    }
    # Missing coordinating conjunction/punctuation that could serve
    # as the coap head in the Prague coordination style.
    # Example: "Oběžoval ho hmyz [#Separ] apod."
    elsif($tlemma eq '#Separ')
    {
        $anode->set_form('a') if($language eq 'cs');
        $anode->set_tag('CCONJ');
        $anode->iset()->set_hash({'pos' => 'conj', 'conjtype' => 'coor'});
    }
    # Foreign expressions are captured as lists of nodes, they are
    # headed by a generated node '#Forn', this node has the functor
    # that corresponds to the function of the foreign expression in
    # the surrounding sentence. It should get 'X'.
    else
    {
        $anode->set_tag('X');
    }
}



#------------------------------------------------------------------------------
# Czech-specific: According to morphological features collected from the
# governing verb, generates the corresponding form of a personal pronoun.
#------------------------------------------------------------------------------
sub set_personal_pronoun_form
{
    my $self = shift;
    my $anode = shift; # the pronoun node
    my $aparent = shift; # parent of the pronoun in the enhanced a-graph (at most one now; undef if the pronoun is attached to the root)
    my $tparent = shift; # parent of the pronoun in the t-tree
    my $functor = shift; # functor of the corresponding t-node
    my $iset = $anode->iset();
    my $case = $self->guess_case($anode, $aparent, $tparent, $functor);
    # If the pronoun represents the subject of a verb, we can guess its morphological
    # features from the governing verb. We do not know yet whether it is a subject —
    # that will have to be guessed, too. But if the functor is ACT and the parent is
    # an active verb, or the functor is PAT and the parent is a passive participle,
    # then we are likely dealing with a subject.
    # Rather than asking about is_active(), we ask about !is_passive() because certain
    # verb forms, such as the imperative, do not have the voice feature, unfortunately.
    if(defined($aparent) && !$aparent->is_root() &&
       ($functor eq 'ACT' && !$self->is_passive($aparent) ||
        $functor eq 'ACT.cop' || # if the ACT was attached directly to copula, it does not matter whether the nominal predicate was a passive participle or not
        $functor eq 'PAT' && $self->is_passive($aparent)))
    {
        $self->get_verb_features($aparent, $iset);
    }
    $iset->set_case($case);
    my $form = 'on';
    # If the pronoun modifies an eventive noun ('spojování obcí někým'), it is
    # attached as 'nmod' and its case is set to genitive or instrumental. We
    # don't know its person, number and gender, so it is better to use an
    # indefinite rather than a personal form. For instance, in the instrumental
    # we cannot choose between "mnou/tebou/jím/jí/námi/vámi/jimi", so we simply
    # use "někým". The same problem occurs with non-nominative arguments of
    # verbs.
    ###!!! It may be possible to resolve this later using coreference. But now
    ###!!! we cannot follow the coreference links yet.
    if($iset->is_genitive())
    {
        $form = 'někoho'; # mne/můj/tebe/tvůj/jeho/jí/její/nás/náš/vás/váš/jich/jejich
    }
    elsif($iset->is_ablative())
    {
        $form = 'od_někoho'; # mne/tebe/něj/ní/nás/vás/nich
        $iset->set_case('gen');
    }
    elsif($iset->is_dative())
    {
        $form = 'někomu'; # mně/mi/tobě/ti/jemu/mu/jí/nám/vám/jim
    }
    elsif($iset->is_accusative())
    {
        $form = 'někoho'; # mne/mě/tebe/tě/jeho/ho/ji/nás/vás/je
    }
    elsif($iset->is_benefactive())
    {
        $form = 'pro_někoho'; # mne/mě/tebe/tě/něj/ni/nás/vás/ně
        $iset->set_case('acc');
    }
    elsif($iset->is_locative())
    {
        $form = 'někom'; # mně/tobě/něm/ní/nás/vás/nich
    }
    elsif($iset->is_instrumental())
    {
        $form = 'někým'; # mnou/tebou/jím/jí/námi/vámi/jimi
    }
    # Some verbs have just Gender=Fem,Neut|Number=Plur,Sing ('ona dělala').
    elsif($iset->is_singular() && $iset->is_plural() && $iset->is_feminine() && $iset->is_neuter())
    {
        $form = 'ona';
    }
    elsif($iset->number() eq 'plur')
    {
        if($iset->person() eq '1')
        {
            $form = 'my';
        }
        elsif($iset->person() eq '2')
        {
            $form = 'vy';
        }
        else
        {
            if($iset->contains('gender', 'fem'))
            {
                $form = 'ony';
            }
            elsif($iset->contains('gender', 'neut'))
            {
                $form = 'ona';
            }
            elsif($iset->contains('animacy', 'inan'))
            {
                $form = 'ony';
            }
            else
            {
                $form = 'oni';
            }
        }
    }
    else # not plural
    {
        if($iset->person() eq '1')
        {
            $form = 'já';
        }
        elsif($iset->person() eq '2')
        {
            if($iset->polite() eq 'form')
            {
                $form = 'vy';
            }
            else
            {
                $form = 'ty';
            }
        }
        else
        {
            if($iset->contains('gender', 'fem'))
            {
                $form = 'ona';
            }
            elsif($iset->contains('gender', 'neut'))
            {
                $form = 'ono';
            }
            else
            {
                $form = 'on';
            }
        }
    }
    $anode->set_form($form);
    return $form;
}



#------------------------------------------------------------------------------
# Czech-specific: According to the governing verb and the functor, generates
# the corresponding form of an indefinite pronoun (#Gen).
#------------------------------------------------------------------------------
sub set_indefinite_pronoun_form
{
    my $self = shift;
    my $anode = shift; # the pronoun node
    my $aparent = shift; # parent of the pronoun in the enhanced a-graph (at most one now; undef if the pronoun is attached to the root)
    my $tparent = shift; # parent of the pronoun in the t-tree
    my $functor = shift; # functor of the corresponding t-node
    my $iset = $anode->iset();
    my $case = $self->guess_case($anode, $aparent, $tparent, $functor);
    $iset->set_case($case);
    my $form = 'někdo';
    if($iset->is_genitive())
    {
        $form = 'někoho';
    }
    elsif($iset->is_ablative())
    {
        $form = 'od_někoho';
        $iset->set_case('gen');
    }
    elsif($iset->is_dative())
    {
        $form = 'někomu';
    }
    elsif($iset->is_accusative())
    {
        $form = 'někoho';
    }
    elsif($iset->is_benefactive())
    {
        $form = 'pro_někoho';
        $iset->set_case('acc');
    }
    elsif($iset->is_instrumental())
    {
        $form = 'někým';
    }
    $anode->set_form($form);
    return $form;
}



#------------------------------------------------------------------------------
# Czech-specific: Guesses morphological case of an argument of a verb, based on
# the lemma of the verb and the functor of the argument.
#------------------------------------------------------------------------------
sub guess_case
{
    my $self = shift;
    my $anode = shift; # generated node (pronoun or even noun) whose case is being guessed
    my $aparent = shift; # parent of the node in the enhanced a-graph (at most one now; undef if the pronoun is attached to the root)
    my $tparent = shift; # parent of the corresponding t-node in the t-tree
    my $functor = shift; # functor of the corresponding t-node
    my $case = 'nom';
    # If we cannot access the parent node (because it is the root), some heuristics cannot be used.
    if(defined($aparent))
    {
        # For some reason, generated copies of nouns in coordinations tend to
        # be attached to the source of the copy. Then we assume that the case
        # should be the same. (It indeed should if they are really conjuncts
        # of the same coordination.)
        if(defined($anode->form()) && $anode->form() eq $aparent->form())
        {
            $case = $aparent->iset()->case();
        }
        elsif($aparent->is_noun())
        {
            # Actors of intransitive nouns are likely to be expressed in genitive: 'někoho (něčí) chůze, pád, spánek, chrápání'
            # Actors of transitives sometimes sound better in the instrumental: 'spojování něčeho někým'
            # However, this seems to work with verbal nouns ('-ní', '-tí') but not with other eventive nouns ('příležitost').
            if($functor eq 'ACT' && defined($aparent) && $aparent->is_verbal_noun() && defined($tparent) && scalar(grep {$_->functor() eq 'PAT'} ($tparent->children())) > 0)
            {
                $case = 'ins';
            }
            elsif($functor eq 'BEN')
            {
                # There is no benefactive case in Czech but we use it to signal the
                # preposition "pro". Later we will create the form with "pro" and
                # change the case to 'acc'.
                $case = 'ben';
            }
            # dostat od někoho (ORIG)
            elsif($functor eq 'ORIG')
            {
                # There is no ablative case in Czech but we use it to signal the
                # preposition "od". Later we will create the form with "od" and
                # change the case to 'gen'.
                $case = 'abl';
            }
            else
            {
                $case = 'gen';
            }
        }
        elsif($functor eq 'ACT')
        {
            # Actors of passive participles of transitive verbs are likely to be their instrumental/oblique agents.
            if($self->is_passive($aparent))
            {
                $case = 'ins';
            }
            # dařit se, podařit se někomu
            elsif($aparent->lemma() =~ m/dařit$/)
            {
                $case = 'dat';
            }
            else
            {
                $case = 'nom';
            }
        }
        elsif($functor eq 'ACT.cop')
        {
            $case = 'nom';
        }
        elsif($functor eq 'PAT')
        {
            # Patients of passive participles of transitive verbs are likely to be their nominative subjects.
            if($self->is_passive($aparent))
            {
                $case = 'nom';
            }
            # stačit, postačit, vystačit někomu
            # škodit, uškodit někomu (ale ne poškodit někoho)
            # vyplatit se někomu
            elsif($aparent->lemma() =~ m/^(postačit|stačit|škodit|uškodit|vyplatit|vystačit)$/)
            {
                $case = 'dat';
            }
            else
            {
                $case = 'acc';
            }
        }
        elsif($functor eq 'ADDR')
        {
            # stimulovat někoho
            # žádat, požádat někoho (ale ne vyžádat si od někoho)
            if($aparent->lemma() =~ m/^(požádat|stimulovat|žádat)$/)
            {
                $case = 'acc';
            }
            else
            {
                $case = 'dat';
            }
        }
        elsif($functor eq 'BEN')
        {
            # There is no benefactive case in Czech but we use it to signal the
            # preposition "pro". Later we will create the form with "pro" and
            # change the case to 'acc'.
            $case = 'ben';
        }
        # dostat od někoho (ORIG)
        elsif($functor eq 'ORIG')
        {
            # There is no ablative case in Czech but we use it to signal the
            # preposition "od". Later we will create the form with "od" and
            # change the case to 'gen'.
            $case = 'abl';
        }
    }
    else # not defined $aparent
    {
        if($functor eq 'PAT')
        {
            $case = 'acc';
        }
        elsif($functor eq 'ADDR')
        {
            $case = 'dat';
        }
        elsif($functor eq 'BEN')
        {
            # There is no benefactive case in Czech but we use it to signal the
            # preposition "pro". Later we will create the form with "pro" and
            # change the case to 'acc'.
            $case = 'ben';
        }
        # dostat od někoho (ORIG)
        elsif($functor eq 'ORIG')
        {
            # There is no ablative case in Czech but we use it to signal the
            # preposition "od". Later we will create the form with "od" and
            # change the case to 'gen'.
            $case = 'abl';
        }
        else
        {
            $case = 'nom';
        }
    }
    return $case;
}



#------------------------------------------------------------------------------
# Gets morphological features of a predicate. This function can be called for
# a parent of an empty node, if the empty node is assumed to be the subject,
# and project the features to the features of the empty node.
#------------------------------------------------------------------------------
sub get_verb_features
{
    my $self = shift;
    my $node = shift; # node where to get the features from
    my $iset = shift; # iset structure where to set the pronominal features
    # The node may not be verb but it may be a nominal predicate and there may
    # still be auxiliary children with more information.
    my $person = '';
    my $number = '';
    my $gender = '';
    my $polite = '';
    while(1)
    {
        my $niset = $node->iset();
        my $nperson = $niset->get_joined('person');
        my $nnumber = $niset->get_joined('number');
        my $ngender = $niset->get_joined('gender');
        if($person eq '' && $nperson ne '')
        {
            $person = $nperson;
        }
        # dělala = Fem Sing or Neut Plur
        # But it can be disambiguated by a 1st/2nd person auxiliary (dělala jsem).
        if($number eq '' && $nnumber ne '' || $number eq 'plur|sing' && $nnumber =~ m/^(sing|plur)$/)
        {
            $number = $nnumber;
        }
        if($gender eq '' && $ngender ne '')
        {
            $gender = $ngender;
        }
        if($gender eq 'fem|neut')
        {
            if($ngender =~ m/^(fem|neut)$/)
            {
                $gender = $ngender;
            }
            elsif($number eq 'sing')
            {
                $gender = 'fem';
            }
            elsif($number eq 'plur')
            {
                $gender = 'neut';
            }
        }
        my @auxiliaries = grep {$_->iset()->is_auxiliary()} ($node->get_children());
        foreach my $aux (@auxiliaries)
        {
            $niset = $aux->iset();
            my $nperson = $niset->get_joined('person');
            my $nnumber = $niset->get_joined('number');
            my $ngender = $niset->get_joined('gender');
            if($person eq '' && $nperson ne '')
            {
                $person = $nperson;
            }
            if($number eq '' && $nnumber ne '' || $number eq 'plur|sing' && $nnumber =~ m/^(sing|plur)$/)
            {
                $number = $nnumber;
            }
            # Vykání (polite 2nd person in Czech): auxiliary is in plural, participle respects the semantic number (singular or plural).
            if($number eq 'sing' && $nnumber eq 'plur' && $person eq '2')
            {
                $polite = 'form';
            }
            if($gender eq '' && $ngender ne '')
            {
                $gender = $ngender;
            }
            if($gender eq 'fem|neut')
            {
                if($ngender =~ m/^(fem|neut)$/)
                {
                    $gender = $ngender;
                }
                elsif($number eq 'sing')
                {
                    $gender = 'fem';
                }
                elsif($number eq 'plur')
                {
                    $gender = 'neut';
                }
            }
        }
        # An open complement (xcomp) of another verb is often non-finite and the
        # features can be found at the matrix verb and its auxiliaries.
        if($node->deprel() =~ m/^xcomp(:|$)/)
        {
            $node = $node->parent();
        }
        else
        {
            last;
        }
    }
    $iset->set_person($person) if(defined($person) && $person ne '');
    $iset->set_number($number) if(defined($number) && $number ne '');
    $iset->set_gender($gender) if(defined($gender) && $gender ne '');
    $iset->set_polite($polite) if(defined($polite) && $polite ne '');
}



#------------------------------------------------------------------------------
# Finds out whether a predicate is passive, which influences whether its ACT
# argument is nominative nsubj, or instrumental obl:agent. This function looks
# at the morphological features of the predicate (is it a passive participle?)
# Note however that one also has to consider whether the participle appears
# with a copula. In the t-tree, the pronoun may be an ACT dependent of the
# copula or a PAT dependent of the participle, but in both cases it should
# become a nsubj (or maybe nsubj:pass) in nominative:
# "jsem opotřebovaný já", not "jsem opotřebovaný mnou/někým".
#------------------------------------------------------------------------------
sub is_passive
{
    my $self = shift;
    my $node = shift; # the predicate node
    return 0 if(!$node->is_participle());
    return 0 if(!$node->iset()->is_passive());
    return 1;
}



#------------------------------------------------------------------------------
# Finds out whether a node depended in the t-tree on a copula that is now
# attached to its parent in the a-tree (UD).
#------------------------------------------------------------------------------
sub tnode_depends_on_copula
{
    my $self = shift;
    my $tnode = shift;
    my $anode = $tnode->parent()->get_lex_anode();
    return 0 if(!defined($anode));
    return $anode->deprel() =~ m/^cop(:|$)/;
}



#------------------------------------------------------------------------------
# Gets the parent of the generated node in the t-tree, and the corresponding
# a-node in the a-tree (enhanced graph). Tries to adjust the parent based on
# the known differences between the UD guidelines and the Prague style.
#------------------------------------------------------------------------------
sub get_parent
{
    my $self = shift;
    my $tnode = shift; # the generated t-node for which we are creating a counterpart in the enhanced graph
    my $tparent = $tnode->parent();
    my $aparent = $tparent->get_lex_anode();
    return ($tparent, $aparent) if(!defined($aparent));
    my $functor = $tnode->functor();
    # In PDT, coordination of verbs is headed by the coordinating conjunction.
    # In UD, it is headed by the first conjunct.
    if($tparent->is_coap_root())
    {
        my @tmembers = sort {$a->ord() <=> $b->ord()} ($tparent->get_coap_members());
        if(scalar(@tmembers) > 0)
        {
            $tparent = $tmembers[0];
            $aparent = $tparent->get_lex_anode();
            return ($tparent, $aparent) if(!defined($aparent));
        }
    }
    # In PDT, copula verb heads the subject (ACT) and the nominal predicate (PAT).
    # In UD, the copula depends on the nominal predicate, and the subject should be attached to it.
    if($aparent->deprel() =~ m/^cop(:|$)/ && $functor eq 'ACT')
    {
        $aparent = $aparent->parent();
        ###!!! It is not clear whether we need to synchronize the $tparent.
    }
    # In PDT, modal verb lacks a t-node.
    # In UD (for Czech), it heads the lexical verb, which is its xcomp.
    if($aparent->deprel() =~ m/^xcomp(:|$)/ && $functor eq 'ACT')
    {
        while($aparent->deprel() =~ m/^xcomp(:|$)/)
        {
            my $agp = $aparent->parent();
            if($agp->lemma() =~ m/^(muset|mít|smět|moci|chtít)$/)
            {
                $aparent = $agp;
            }
            else
            {
                last;
            }
        }
    }
    return ($tparent, $aparent);
}



#------------------------------------------------------------------------------
# Guesses the UD dependency relation based on tectogrammatical functor.
###!!! This is currently very rough and it could be improved!
#------------------------------------------------------------------------------
sub guess_deprel
{
    my $self = shift;
    my $aparent = shift;
    my $anode = shift;
    my $functor = shift;
    my $deprel = 'dep';
    if($functor =~ m/^(DENOM|PAR|PRED)$/)
    {
        $deprel = 'parataxis';
    }
    elsif($functor =~ m/^(PARTL)$/)
    {
        $deprel = 'discourse';
    }
    elsif($functor =~ m/^(VOCAT)$/)
    {
        $deprel = 'vocative';
    }
    # Most empty nodes are pronouns, hence we assume that the dependent is nominal (rather than clausal).
    ###!!! The arguments may correspond to nsubj, obj or obl:arg.
    ###!!! We should consider the voice to distinguish between nsubj and nsubj:pass;
    ###!!! even then it will not work for certain classes of verbs.
    elsif($functor =~ m/^(ACT)$/)
    {
        $deprel = $aparent->is_noun() ? 'nmod' : $anode->is_nominative() || $anode->iset()->case() eq '' ? 'nsubj' : $anode->is_accusative() ? 'obj' : $anode->is_instrumental() ? 'obl:agent' : 'obl:arg';
    }
    elsif($functor =~ m/^(ACT\.cop)$/)
    {
        # The nominal predicate may be a passive participle, but if the pronoun was attached to the copula, it will not be nsubj:pass.
        # On the other hand, if the pronoun was attached as PAT to the participle, it will become nsubj:pass regardless of whether the verb "být" is attached as 'cop' or as 'aux:pass'.
        $deprel = 'nsubj';
    }
    elsif($functor =~ m/^(PAT)$/)
    {
        $deprel = $aparent->is_noun() ? 'nmod' : $anode->is_accusative() ? 'obj' : $anode->is_nominative() || $anode->iset()->case() eq '' ? 'nsubj:pass' : 'obl:arg';
    }
    elsif($functor =~ m/^(ADDR|EFF|ORIG)$/)
    {
        $deprel = $aparent->is_noun() ? 'nmod' : 'obl:arg';
    }
    # Adjuncts could be obl, advmod, advcl; we use always obl.
    elsif($functor =~ m/^(ACMP|AIM|BEN|CAUS|CNCS|COMPL|COND|CONTRD|CPR|CRIT|DIFF|DIR[123]|EXT|HER|INTT|LOC|MANN|MEANS|REG|RESL|RESTR|SUBS|TFHL|TFRWH|THL|THO|TOWH|TPAR|TSIN|TTILL|TWHEN)$/)
    {
        $deprel = $aparent->is_noun() ? 'nmod' : 'obl';
    }
    # Adnominal arguments and adjuncts could be nmod, amod, det, nummod; we use always nmod.
    elsif($functor =~ m/^(APP|AUTH|DESCR|ID|MAT|RSTR)$/)
    {
        $deprel = 'nmod';
    }
    # ATT = speaker's attitude
    elsif($functor =~ m/^(ATT)$/)
    {
        $deprel = 'advmod';
    }
    # CM = modification of coordination ("ale _dokonce_...")
    elsif($functor =~ m/^(CM)$/)
    {
        $deprel = 'cc';
    }
    # CPHR = nominal part of compound predicate ("dostali _rozkaz_")
    elsif($functor =~ m/^(CPHR)$/)
    {
        $deprel = 'obj';
    }
    # DPHR = dependent part of idiom (phraseme) ("jde mi _na nervy_"; "široko _daleko_"; "křížem _krážem_")
    elsif($functor =~ m/^(DPHR)$/)
    {
        # DPHR could be various things in the surface syntax.
        $deprel = 'dep';
    }
    # FPHR = part of foreign expression
    elsif($functor =~ m/^(FPHR)$/)
    {
        $deprel = 'flat:foreign';
    }
    # NE = part of named entity (only PCEDT)
    elsif($functor =~ m/^(NE)$/)
    {
        $deprel = 'flat:name';
    }
    # INTF = expletive subject
    elsif($functor =~ m/^(INTF)$/)
    {
        $deprel = 'expl';
    }
    # MOD = some modal expressions ("_pravděpodobně_ přijdeme"; "_asi_ před týdnem jsem dostal dopis").
    # PREC = preceding context ("pak", "naopak")
    # RHEM = rhematizer ("jen", "teprve", "ještě")
    elsif($functor =~ m/^(MOD|PREC|RHEM)$/)
    {
        $deprel = 'advmod';
    }
    # The functors for head nodes of paratactic structures should not be used in UD
    # where paratactic structures are annotated in the Stanford style. Nevertheless,
    # we list them here for completeness.
    elsif($functor =~ m/^(ADVS|APPS|CONFR|CONJ|CONTRA|CSQ|DISJ|GRAD|OPER|REAS)$/)
    {
        $deprel = 'cc';
    }
    return $deprel;
}



#------------------------------------------------------------------------------
# Finds a linear position for the empty node. We used to place it between the
# current and the previous t-node based on their deep order, and using lexical
# a-node references to map t-nodes on non-empty a-nodes. However, it did not
# always yield acceptable results (due to different UD tree structure, ignored
# function words etc.) Some empty nodes occurred far from their parents, and
# there were spurious non-projectivities.
#------------------------------------------------------------------------------
sub position_empty_node
{
    my $self = shift;
    my $anode = shift; # the empty node to be positioned (decimal id)
    my $aparent = shift; # the parent of the empty node in the enhanced graph
    my $lastmajor = shift; # the major id (ord) of the last (following deep order of t-nodes) a-node that is a lexical counterpart of a t-node
    my $lastminor = shift; # array reference: for each major id, the highest minor id used so far
    my ($major, $minor);
    if($aparent->is_root())
    {
        $major = $lastmajor;
    }
    else
    {
        # Insert the empty node right before its parent in the enhanced graph.
        # That will prevent non-projectivities and make the data more easily readable for a human.
        $major = $aparent->ord()-1;
    }
    $minor = ++$lastminor->[$major];
    $anode->wild()->{enord} = "$major.$minor";
}



#------------------------------------------------------------------------------
# Adjusts the structural position of an empty node that is a copy of a noun in
# coordination, whereas there is coordination of adjectival modifiers on the
# surface. Example: "akcí pro domácí (turisty) i cizí turisty". The copied node
# was generated as a leaf but we want the corresponding adjective re-attached
# to it in the enhanced graph. Also, the copied node is now probably attached
# to the source/surface conjunct as nmod. If the source conjunct happens to be
# the first conjunct, we only have to relabel the relation to conj. But if the
# source conjunct is not the first one, we must also restructure the coordina-
# tion. Before that, we may want to adjust the linear position of the copied
# node so that it is more natural with respect to the adjective; therefore,
# this method should be called after the generic position_empty_node().
#------------------------------------------------------------------------------
sub adjust_copied_conjunct
{
    my $self = shift;
    my $copy_anode = shift;
    my $copy_tnode = shift;
    my $document = $copy_anode->get_document();
    # We should not use this method for verbs. It would apply to numerous
    # instances of gapping, which should be solved eventually, but differently.
    return if(!$copy_anode->is_noun());
    # Is the corresponding t-node a member of coordination or apposition?
    # Note: In the future we may find out that a similar procedure is needed
    # for other constructions that are not coordination or apposition. But for
    # now let's stick to the prototypical situation.
    return if(!$copy_tnode->is_member());
    # Does the corresponding t-node have children (such as the adjective)?
    my @tchildren = $copy_tnode->get_children();
    return if(scalar(@tchildren) == 0);
    # We will need the a-nodes that correspond to the t-children. Typically,
    # the children are represented on the surface and their a-nodes exist.
    # However, if we also want to process generated children, we should move
    # this method to a separate block and call it after the current block has
    # finished generating empty nodes for all generated t-nodes.
    my @achildren = Treex::Core::Node::A::sort_nodes_by_conllu_ids(grep {defined($_)} (map {$_->get_lex_anode()} (@tchildren)));
    return if(scalar(@achildren) == 0);
    # Re-attach the children to the copied a-node in the enhanced graph.
    foreach my $achild (@achildren)
    {
        # This should not lead to self-loops but double check.
        next if($achild == $copy_anode);
        # This block should be run after A2A::CopyBasicToEnhancedUD and before
        # A2A::AddEnhancedUD, so there should be just one incoming enhanced
        # edge. But if there are more, remove all of them.
        $achild->clear_enhanced_deps();
        my $edeprel = 'dep';
        if($copy_anode->is_noun())
        {
            if($achild->is_determiner())
            {
                $edeprel = 'det';
            }
            elsif($achild->is_cardinal())
            {
                $edeprel = 'nummod';
            }
            elsif($achild->is_adjective())
            {
                $edeprel = 'amod';
            }
            elsif($achild->is_verb())
            {
                $edeprel = 'acl';
            }
            else
            {
                $edeprel = 'nmod';
            }
        }
        $achild->add_enhanced_dependency($copy_anode, $edeprel);
    }
    # Adjust the linear position of the copied a-node so that it immediately
    # follows its rightmost child (assuming the child is an adjective and the
    # language is Czech, this should be a naturally sounding position).
    $copy_anode->shift_empty_node_after_node($achildren[-1]);
    # The copied a-node should be attached to its parent as conj. But if it
    # precedes it in the linear order, the relation should have the opposite
    # direction.
    my @eparents = $copy_anode->get_enhanced_parents();
    if(scalar(@eparents) == 1)
    {
        my $eparent = $eparents[0];
        my $cmp = Treex::Core::Node::A::cmp_conllu_ids($copy_anode->get_conllu_id(), $eparent->get_conllu_id());
        if($cmp < 0)
        {
            # The copied node precedes its parent. We must swap the parent and
            # the child so that all conj relations go left-to-right.
            $copy_anode->set_enhanced_deps($eparent->get_enhanced_deps());
            $eparent->clear_enhanced_deps();
            $eparent->add_enhanced_dependency($copy_anode, 'conj');
        }
        else # no redirecting, just setting the edeprel
        {
            $copy_anode->clear_enhanced_deps();
            $copy_anode->add_enhanced_dependency($eparent, 'conj');
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::GenerateEmptyNodes

=item DESCRIPTION

Generates an empty node (as in enhanced UD graphs, in the form recognized by
Write::CoNLLU) for every generated t-node, and stores in its wild attributes
a reference to the corresponding t-node (in the same fashion as GenerateA2TRefs
stores references from real a-nodes to corresponding t-nodes).

As a side-effect, all a-nodes that have a corresponding t-node (i.e., not just
the newly generated empty nodes) will have the functor stored as a misc
attribute.

While it may be useful to run T2A::GenerateA2TRefs before the conversion from
Prague to UD (so that the conversion procedure has access to tectogrammatic
annotation), calling this block is better postponed until the basic UD tree is
ready. The empty nodes will participate only in enhanced dependencies, so they
are not needed earlier. But they are represented using fake a-nodes, which
might confuse the conversion functions that operate on the basic (a-)tree.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

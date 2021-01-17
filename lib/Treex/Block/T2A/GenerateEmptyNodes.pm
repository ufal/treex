package Treex::Block::T2A::GenerateEmptyNodes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_zone
{
    my $self = shift;
    my $zone = shift;
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
        if($tnode->is_generated())
        {
            my $anode = $aroot->create_child();
            $anode->set_deprel('dep:empty');
            # Make sure we can access the t-node from the new a-node and vice versa.
            $anode->wild()->{'tnode.rf'} = $tnode->id();
            $tnode->wild()->{'anode.rf'} = $anode->id();
            $anode->wild()->{enhanced} = [];
            $lastminor[$major]++;
            $anode->wild()->{enord} = "$major.$lastminor[$major]";
            $anode->shift_after_node($lastanode);
            $lastanode = $anode;
            my $tlemma = $tnode->t_lemma();
            $anode->set_lemma($tlemma);
            # Store the functor in MISC. It may be useful to understand why the empty node is there.
            my $functor = $tnode->functor() // 'Unknown';
            $anode->set_misc_attr('Functor', $functor);
            # We need an enhanced relation to make the empty node connected with
            # the enhanced dependency graph. Try to propagate the dependency from
            # the t-tree. (The parent may also help us estimate features of the
            # generated node, such as person of #PersPron. Note however that some
            # of the features may also be available as grammatemes.)
            my $tparent = $tnode->parent();
            my $aparent = $tparent->get_lex_anode();
            # The $aparent may not exist or it may be in another sentence, in
            # which case we cannot use it.
            if(defined($aparent) && $aparent->get_root() == $aroot)
            {
                my $deprel = 'dep';
                if(defined($functor))
                {
                    $deprel = $self->guess_deprel($aparent, $functor);
                }
                $anode->add_enhanced_dependency($aparent, $deprel);
                $self->get_verb_features($aparent, $anode->iset());
            }
            # Without connecting the empty node at least to the root, it would not
            # be printed and the graph would not be valid.
            ###!!! It may be possible to attach the node to another empty node.
            ###!!! We would have to generate all nodes first, then to connect them.
            ###!!! However, at present we generate all empty nodes as leaves.
            else
            {
                $anode->add_enhanced_dependency($aroot, 'root');
            }
            # If the generated node is a copy of a real node, we may be able to
            # copy its attributes.
            my $source_anode = $tnode->get_lex_anode();
            if(defined($source_anode))
            {
                $anode->set_form($source_anode->form());
                $anode->set_tag($source_anode->tag());
                $anode->iset()->set_hash($source_anode->iset()->get_hash());
            }
            else
            {
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
                if($tlemma =~ m/^\#(Unsp|Q?Cor|Rcp|Oblfm|Benef)$/)
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
                    if($iset->number() eq 'plur')
                    {
                        if($iset->person() eq '1')
                        {
                            $anode->set_form('my');
                        }
                        elsif($iset->person() eq '2')
                        {
                            $anode->set_form('vy');
                        }
                        else
                        {
                            if($iset->gender() eq 'fem')
                            {
                                $anode->set_form('ony');
                            }
                            elsif($iset->gender() eq 'neut')
                            {
                                $anode->set_form('ona');
                            }
                            elsif($iset->animacy() eq 'inan')
                            {
                                $anode->set_form('ony');
                            }
                            else
                            {
                                $anode->set_form('oni');
                            }
                        }
                    }
                    else
                    {
                        if($iset->person() eq '1')
                        {
                            $anode->set_form('já');
                        }
                        elsif($iset->person() eq '2')
                        {
                            $anode->set_form('ty');
                        }
                        else
                        {
                            if($iset->gender() eq 'fem')
                            {
                                $anode->set_form('ona');
                            }
                            elsif($iset->gender() eq 'neut')
                            {
                                $anode->set_form('ono');
                            }
                            else
                            {
                                $anode->set_form('on');
                            }
                        }
                    }
                }
                elsif($tlemma eq '#Gen')
                {
                    # Very often, if a #Gen is used in coreference, its functor is BEN (beneficiary).
                    if($functor eq 'BEN')
                    {
                        $anode->set_form('pro_někoho');
                    }
                    else
                    {
                        $anode->set_form('někdo');
                    }
                    $anode->set_tag('PRON');
                    $anode->iset()->set_hash({'pos' => 'noun', 'prontype' => 'ind'});
                }
                elsif($tlemma eq '#Neg')
                {
                    $anode->set_form('ne');
                    $anode->set_tag('PART');
                    $anode->iset()->set_hash({'pos' => 'part', 'polarity' => 'neg'});
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
                    $anode->set_form('tak');
                    $anode->set_tag('ADV');
                    $anode->iset()->set_hash({'pos' => 'adv'});
                }
                # Elided positive in comparison.
                # Example: Udělal to [stejně], jako to udělal Tonda.
                # Example: Poslanec je [stejný] člověk jako [je] každý jiný [člověk].
                elsif($tlemma eq '#Equal')
                {
                    $anode->set_form('stejný/stejně');
                    # We do not know whether it should be ADJ or ADV, so we go by X.
                    $anode->set_tag('X');
                }
                # #Some
                # Example: Je stejný jako já [jsem nějaký]. (We cannot copy "stejný" here, so we generate '#Some'.)
                elsif($tlemma eq '#Some')
                {
                    $anode->set_form('nějaký');
                    $anode->set_tag('ADJ');
                    $anode->iset()->set_hash({'pos' => 'adj'});
                }
                # Missing totalizer '#Total'.
                # Example: Mimo datum se píší [všechny] řadové číslice slovy.
                # Example: Kromě Jihočeské keramiky nepatří tyto firmy mezi nejsilnější. (annotated as "firmy [všechny] kromě Jihočeské keramiky")
                elsif($tlemma eq '#Total')
                {
                    $anode->set_form('všichni');
                    $anode->set_tag('DET');
                    $anode->iset()->set_hash({'pos' => 'adj', 'prontype' => 'tot'});
                }
                # Missing coordinating conjunction/punctuation that could serve
                # as the coap head in the Prague coordination style.
                # Example: "Oběžoval ho hmyz [#Separ] apod."
                elsif($tlemma eq '#Separ')
                {
                    $anode->set_form('a');
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
            }
        }
    }
}



#------------------------------------------------------------------------------
# Gets morphological features of the parent. It may be useful if the parent is
# a verb and the empty node is a personal pronoun.
#------------------------------------------------------------------------------
sub get_verb_features
{
    my $self = shift;
    my $node = shift; # node where to get the features from
    my $iset = shift; # iset structure where to set the pronominal features
    # The node may not be verb but it may be a nominal predicate and there may
    # still be auxiliary children with more information.
    my ($person, $number, $gender);
    while(1)
    {
        my $niset = $node->iset();
        $person = $niset->person() if(!defined($person) && $niset->person() ne '');
        $number = $niset->number() if(!defined($number) && $niset->number() ne '');
        $gender = $niset->gender() if(!defined($gender) && $niset->gender() ne '');
        my @auxiliaries = grep {$_->is_auxiliary()} ($node->get_children());
        foreach my $aux (@auxiliaries)
        {
            $niset = $aux->iset();
            $person = $niset->person() if(!defined($person) && $niset->person() ne '');
            $number = $niset->number() if(!defined($number) && $niset->number() ne '');
            $gender = $niset->gender() if(!defined($gender) && $niset->gender() ne '');
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
}



#------------------------------------------------------------------------------
# Guesses the UD dependency relation based on tectogrammatical functor.
###!!! This is currently very rough and it could be improved!
#------------------------------------------------------------------------------
sub guess_deprel
{
    my $self = shift;
    my $aparent = shift;
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
    ###!!! The arguments may correspond to nsubj, obj or obl:arg.
    ###!!! We should consider the voice to distinguish between nsubj and nsubj:pass;
    ###!!! even then it will not work for certain classes of verbs.
    ###!!! We also don't know whether the argument is nominal (nsubj) or clausal (csubj)
    ###!!! but since we typically pretend the empty node corresponds to a pronoun, it should be nominal.
    elsif($functor =~ m/^(ACT)$/)
    {
        $deprel = $aparent->is_noun() ? 'nmod' : 'nsubj';
    }
    elsif($functor =~ m/^(PAT)$/)
    {
        $deprel = $aparent->is_noun() ? 'nmod' : 'obj';
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

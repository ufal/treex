package Treex::Block::HamleDT::SA::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_root_punct($root);
    $self->fix_case_mark($root);
}



#------------------------------------------------------------------------------
# Fixes known issues in features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        # Ambiguous lemmas with numeric selectors: the number should be moved to MISC (LId attribute).
        if($lemma =~ s/_(\d+)$//)
        {
            $node->set_lemma($lemma);
            $node->wild()->{lid} = $1;
        }
        # The gender, number, person and verbform features cannot occur with adpositions, conjunctions, particles, interjections and punctuation.
        if($iset->pos() =~ m/^(adv|adp|conj|part|int|punc)$/)
        {
            $iset->clear('gender', 'number', 'person', 'verbform');
        }
        # The verbform feature also cannot occur with pronouns, determiners and numerals.
        if($iset->is_pronoun() || $iset->is_numeral())
        {
            $iset->clear('verbform');
        }
        # The mood and tense features can only occur with verbs.
        if(!$iset->is_verb())
        {
            $iset->clear('mood', 'tense');
        }
        # Fix verbal features.
        if($iset->is_verb())
        {
            # Every verb has a verbform. Those that do not have any verbform yet, are probably finite.
            if($iset->verbform() eq '')
            {
                $iset->set('verbform', 'fin');
            }
        }
        # Add pronominal type.
        # https://en.wikipedia.org/wiki/Sanskrit_pronouns_and_determiners
        if($node->is_pronominal())
        {
            #       First Person                                     Second Person
            #       Sing          Dual             Plur              Sing           Dual              Plur
            # Nom   aham          āvām             vayam             tvam           yuvām             yūyam
            # Acc   mām (mā)      āvām (nau)       asmān (naḥ)       tvām (tvā)     yuvām (vām)       yuṣmān (vaḥ)
            # Ins   mayā          āvābhyām         asmābhiḥ          tvayā          yuvābhyām         yuṣmābhiḥ
            # Dat   mahyam (me)   āvābhyām (nau)   asmabhyam (naḥ)   tubhyam (te)   yuvābhyām (vām)   yuṣmabhyam (vaḥ)
            # Abl   mat           āvābhyām         asmat             tvat           yuvābhyā          yuṣmat
            # Gen   mama (me)     āvayoḥ (nau)     asmākam (naḥ)     tava (te)      yuvayoḥ (vām)	  yuṣmākam (vaḥ)
            # Loc   mayi          āvayoḥ           asmāsu            tvayi          yuvayoḥ           yuṣmāsu
            if($lemma =~ m/^(अहम्|अस्मद्|मा)$/)
            {
                $iset->set('prontype', 'prs');
                $iset->set('person', 1);
                $lemma = 'अहम्';
                $node->set_lemma($lemma);
                $node->wild()->{lemma_translit} = 'aham';
            }
            elsif($lemma =~ m/^(त्वद्|युष्मद्)$/)
            {
                $iset->set('prontype', 'prs');
                $iset->set('person', 2);
                $lemma = 'त्वद्';
                $node->set_lemma($lemma);
                $node->wild()->{lemma_translit} = 'tvad';
            }
            elsif($lemma =~ m/^(भवत्|भव)$/)
            {
                $iset->set('prontype', 'prs');
                $iset->set('person', 2);
                $iset->set('politeness', 'pol');
            }
            # There are no third person pronouns. Demonstratives are used instead.
            # There are four demonstratives (cited in neuter singular nominative):
            # tat (that), adaḥ (that, more emphatic), idam (this), etat (this, more emphatic)
            # (česky asi: ten, tamten, ten, tento)
            # Paradigm of tat:
            #       Masc                         Neut                         Fem
            #       Sing     Dual      Plur      Sing     Dual      Plur      Sing     Dual      Plur
            # Nom   saḥ      tau       te        tat      te        tāni      sā       te        tāḥ
            # Acc   tam      tau       tan       tat      te        tāni      tām      te        tāḥ
            # Ins   tena     tābhyām   taiḥ      tena     tābhyām   taiḥ      tayā     tābhyām   tābhiḥ
            # Dat   tasmai   tābhyām   tebhyaḥ   tasmai   tābhyām   tebhyaḥ   tasyai   tābhyām   tābhyaḥ
            # Abl   tasmat   tābhyām   tebhyaḥ   tasmat   tābhyām   tebhyaḥ   tasyāḥ   tābhyām   tābhyaḥ
            # Gen   tasya    tayoḥ     teṣām     tasya    tayoḥ     teṣām     tasyāḥ   tayoḥ     tāsām
            # Loc   tasmin   tayoḥ     teṣu      tasmin   tayoḥ     teṣu      tasyām   tayoḥ     tāsu
            elsif($lemma =~ m/^(तत्|तत्र|तद्|अदस्|असौ|अयम्|इदम्|एतद्|एष|स|ते)$/)
            {
                $iset->set('prontype', 'dem');
                $iset->clear('person');
                if($lemma =~ m/^(तत्|तद्|ते|स)$/)
                {
                    $lemma = 'तद्';
                    $node->set_lemma($lemma);
                    $node->wild()->{lemma_translit} = 'tad';
                }
                elsif($lemma =~ m/^(एतद्|एष)$/)
                {
                    $lemma = 'एतद्';
                    $node->set_lemma($lemma);
                    $node->wild()->{lemma_translit} = 'etad';
                }
                # Paradigm of adaḥ:
                #       Masc                            Neut                            Fem
                #       Sing      Dual       Plur       Sing      Dual       Plur       Sing      Dual       Plur
                # Nom   asau      amū        amī        adaḥ      amū        amūni      asau      amū        amūḥ
                # Acc   amum      amū        amūn       adaḥ      amū        amūni      amūm      amū        amūḥ
                # Ins   amunā     amūbhyām   amībhiḥ    amunā     amūbhyām   amībhiḥ    amuyā     amūbhyām   amūbhiḥ
                # Dat   amuṣmai   amūbhyām   amībhyaḥ   amuṣmai   amūbhyām   amībhyaḥ   amuṣyai   amūbhyām   amūbhyaḥ
                # Abl   amuṣmāt   amūbhyām   amībhyaḥ   amuṣmāt   amūbhyām   amībhyaḥ   amuṣyāḥ   amūbhyām   amūbhyaḥ
                # Gen   amuṣya    amuyoḥ     amīṣām     amuṣya    amuyoḥ     amīṣām     amuṣyāḥ   amuyoḥ     amūṣām
                # Loc   amuṣmin   amuyoḥ     amīṣu      amuṣmin   amuyoḥ     amīṣu      amuṣyām   amuyoḥ     amūṣu
                elsif($lemma =~ m/^(अदस्|असौ)$/)
                {
                    $lemma = 'अदस्';
                    $node->set_lemma($lemma);
                    $node->wild()->{lemma_translit} = 'adas';
                }
                # Paradigm of idam:
                #       Masc                      Neut                        Fem
                #       Sing    Dual     Plur     Sing      Dual     Plur     Sing      Dual     Plur
                # Nom   ayam    imau     ime      idam      ime      imāni    iyam      ime      imāḥ
                # Acc   imam    imau     imān     idam      ime      imāni    imām      ime      imāḥ
                # Ins   anena   ābhyām   ebhiḥ    amunā     ābhyām   ebhiḥ    amuyā     ābhyām   ābhiḥ
                # Dat   asmai   ābhyām   ebhyaḥ   amuṣmai   ābhyām   ebhyaḥ   amuṣyai   ābhyām   ābhyaḥ
                # Abl   asmāt   ābhyām   ebhyaḥ   amuṣmāt   ābhyām   ebhyaḥ   amuṣyāḥ   ābhyām   ābhyaḥ
                # Gen   asya    anayoḥ   eṣām     amuṣya    anayoḥ   eṣām     amuṣyāḥ   anayoḥ   āsām
                # Loc   asmin   anayoḥ   eṣu      amuṣmin   anayoḥ   eṣu      amuṣyām   anayoḥ   āsu
                elsif($lemma =~ m/^(अयम्|इदम्)$/)
                {
                    $lemma = 'इदम्';
                    $node->set_lemma($lemma);
                    $node->wild()->{lemma_translit} = 'idam';
                }
            }
            # Enclitic pronoun enam is used in a few oblique cases and numbers. It mostly refers to persons.
            #           Sing                   Dual                       Plur
            #           Masc    Neut    Fem    Masc     Neut     Fem      Masc   Neut    Fem
            # Acc       enam    enat    enām   enau     ene      ene      enān   enāni   enāḥ
            # Ins       enena   enena
            # Gen,Loc                          enayoḥ   enayoḥ   enayoḥ
            elsif($lemma =~ m/^(एन)$/)
            {
                $iset->set('prontype', 'prs');
                $iset->set('person', 3);
            }
            # Reflexive pronouns:
            # svayam ... indeclinable, pertains to subjects of any person or number
            # ātman ... self ... reflexivity in any case, person and number; form always masculine, even for feminine and neuter subjects
            # svaḥ ... determiner: one's own
            elsif($lemma =~ m/^(आत्मन्|स्व)$/)
            {
                $iset->set('prontype', 'prs');
                $iset->set('reflex', 'reflex');
                $iset->clear('person');
            }
            # Interrogative pronoun kim/ka is inflected like the demonstrative tat; but the form kim is exception (instead of *kat).
            # Other interrogatives: kiyat = how much, how large
            elsif($lemma =~ m/^(क|कति|कथ्|किम्|कियत्|कदाचित्|कधाचिद्|किम्|किं|किंचिद्)$/)
            {
                $iset->set('prontype', 'int');
                $iset->clear('person');
                if($lemma =~ m/^(क|किम्)$/)
                {
                    $lemma = 'क';
                    $node->set_lemma($lemma);
                    $node->wild()->{lemma_translit} = 'ka';
                }
            }
            # Relative pronoun yat is declined like tat. The demonstrative tat also functions as correlative in complex sentences.
            elsif($lemma =~ m/^(यद्|य)$/)
            {
                $iset->set('prontype', 'rel');
                $iset->clear('person');
                $lemma = 'यद्';
                $node->set_lemma($lemma);
                $node->wild()->{lemma_translit} = 'yad';
            }
        }
        # Remove the XPOSTAG value. It is always 'X' and it is not useful.
        # Note that setting undef would result in it later being rewritten by a copy of UPOSTAG.
        $node->set_conll_pos('_');
    }
}



#------------------------------------------------------------------------------
# After changes done to Interset (including part of speech) generates the
# universal part-of-speech tag anew.
#------------------------------------------------------------------------------
sub regenerate_upos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        $node->set_tag($node->iset()->get_upos());
    }
}



#------------------------------------------------------------------------------
# Fixes sentence-final punctuation attached to the artificial root node.
#------------------------------------------------------------------------------
sub fix_root_punct
{
    my $self = shift;
    my $root = shift;
    my @children = $root->children();
    if(scalar(@children)==2 && $children[1]->is_punctuation())
    {
        $children[1]->set_parent($children[0]);
        $children[1]->set_deprel('punct');
    }
}



#------------------------------------------------------------------------------
# Changes the relation between a preposition and a verb (infinitive) from case
# to mark. Miguel has done something in that direction but there are still many
# occurrences where this has not been fixed.
#------------------------------------------------------------------------------
sub fix_case_mark
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'case')
        {
            my $parent = $node->parent();
            # Most prepositions modify infinitives: para preparar, en ir, de retornar...
            if($parent->is_infinitive())
            {
                $node->set_deprel('mark');
            }
        }
    }
    # There is a bug caused by splitting preposition + determiner contractions:
    # "desta vez" ("this time") is a MWE attached directly to the ROOT node.
    if($nodes[0]->parent()->is_root() && $nodes[0]->form() eq 'De' &&
       $nodes[1]->parent()->is_root() && $nodes[1]->form() eq 'esta')
    {
        $nodes[0]->set_deprel('root');
        $nodes[1]->set_parent($nodes[0]);
        $nodes[1]->set_deprel('mwe');
    }
}



#------------------------------------------------------------------------------
# Collects all nodes in a subtree of a given node. Useful for fixing known
# annotation errors, see also get_node_spanstring(). Returns ordered list.
#------------------------------------------------------------------------------
sub get_node_subtree
{
    my $self = shift;
    my $node = shift;
    my @nodes = $node->get_descendants({'add_self' => 1, 'ordered' => 1});
    return @nodes;
}



#------------------------------------------------------------------------------
# Collects word forms of all nodes in a subtree of a given node. Useful to
# uniquely identify sentences or their parts that are known to contain
# annotation errors. (We do not want to use node IDs because they are not fixed
# enough in all treebanks.) Example usage:
# if($self->get_node_spanstring($node) =~ m/^peça a URV em a sua mesada$/)
#------------------------------------------------------------------------------
sub get_node_spanstring
{
    my $self = shift;
    my $node = shift;
    my @nodes = $self->get_node_subtree($node);
    return join(' ', map {$_->form() // ''} (@nodes));
}



1;

=over

=item Treex::Block::HamleDT::SA::FixUD

This is a temporary block that should fix selected known problems in the Sanskrit UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

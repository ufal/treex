package Treex::Block::HamleDT::DE::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # Fix relations before morphology. The fixes depend only on UPOS tags, not on morphology (e.g. NOUN should not be attached as det).
    # And with better relations we will be more able to disambiguate morphological case and gender.
    $self->fix_det_nmod($root);
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_root_punct($root);
    # Other relations will be fixed after morphology and we will use lemmas in the heuristics.
    $self->fix_possessive_determiners($root);
    $self->fix_infinitival_zu($root);
    $self->fix_separable_verb_prefixes($root);
    $self->fix_mwe($root);
}



#------------------------------------------------------------------------------
# Fixes known issues in dependency relations.
#------------------------------------------------------------------------------
sub fix_det_nmod
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    # Identify finite verbs first. We will need them later to disambiguate personal pronouns.
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        # Genitive noun phrases are often attached as det while they should be nmod.
        if($node->is_noun() && !$node->is_pronominal() && $parent->is_noun() && $node->deprel() =~ m/^det(:|$)/)
        {
            $node->set_deprel('nmod');
        }
    }
}



#------------------------------------------------------------------------------
# Fixes known issues in features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # Identify finite verbs first. We will need them later to disambiguate personal pronouns.
    foreach my $node (@nodes)
    {
        if($node->is_verb())
        {
            my $stts = $node->conll_pos();
            if($stts =~ m/^V[VMA]FIN$/)
            {
                $node->iset()->set('verbform', 'fin');
            }
            elsif($stts =~ m/^V[VMA]INF$/)
            {
                $node->iset()->set('verbform', 'inf');
            }
            elsif($stts =~ m/^V[VMA]PP$/)
            {
                $node->iset()->set('verbform', 'part');
            }
        }
    }
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $lcform = lc($node->form());
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        # Conll/pos contains the automatically predicted STTS POS tag.
        my $stts = $node->conll_pos();
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
        # Fix articles. Warning: the indefinite article, "ein", may also be a numeral.
        # The definite article, "der", may also be a demonstrative or relative pronoun.
        if($node->is_pronominal())
        {
            if($lemma eq 'd')
            {
                $lemma = 'der';
                $node->set_lemma($lemma);
                if($stts eq 'ART')
                {
                    # The UPOSTAG was assigned manually while the STTS XPOSTAG was predicted automatically.
                    # If XPOS=ART co-occurs with UPOS=PRON (not compatible), we believe the UPOSTAG and treat the word as demonstrative pronoun.
                    if($node->is_determiner())
                    {
                        $iset->set('prontype', 'art');
                        $iset->set('definiteness', 'def');
                    }
                    else
                    {
                        $iset->set('prontype', 'dem');
                    }
                }
                elsif($stts =~ m/^PD(S|AT)$/)
                {
                    $iset->set('prontype', 'dem');
                }
                elsif($stts =~ m/^PREL(S|AT)$/)
                {
                    $iset->set('prontype', 'rel');
                }
            }
            # The indefinite article has lemma "ein" but sometimes also "eine", "ne" or "eins".
            # The form "ne" is a shortcut for "eine".
            # The form "eins" (if not cardinal numeral) is a shortcut for "eines".
            elsif($lemma =~ m/^(ein[es]?|ne)$/)
            {
                $lemma = 'ein';
                $node->set_lemma($lemma);
                # The UPOSTAG was assigned manually while the STTS XPOSTAG was predicted automatically.
                # If XPOS=ART co-occurs with UPOS=PRON (not compatible), we believe the UPOSTAG and treat the word as indefinite pronoun.
                # Sometimes the XPOSTAG is not ART but PTKVZ, but UPOSTAG is DET. So the annotator thought it was article but the tagger mistook it for separable verb prefix.
                if($node->is_determiner())
                {
                    $iset->set('prontype', 'art');
                    $iset->set('definiteness', 'ind');
                    $stts = 'ART';
                    $node->set_conll_pos($stts);
                }
                else
                {
                    $iset->set('prontype', 'ind');
                    $stts = 'PIS';
                    $node->set_conll_pos($stts);
                }
            }
        }
        # Fix personal pronouns.
        # There are a few cases where the UPOSTAG of a (non-possessive) personal pronoun is DET instead of PRON.
        # These are errors and we will correct them (we ask for is_pronominal(), not is_pronoun(), but then set pos to noun).
        # However, the word "ihr" can also be a possessive determiner and here the error may be in XPOSTAG!
        if($node->is_pronominal() && $stts =~ m/^(PPER|PRF)$/)
        {
            my $reflex = $stts eq 'PRF' ? 'reflex' : '';
            if($lemma eq 'ich')
            {
                my %case = ('ich' => 'nom', 'mir' => 'dat', 'mich' => 'acc');
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 1, 'number' => 'sing', 'case' => $case{$lcform}});
            }
            elsif($lemma eq 'wir')
            {
                my %case = ('wir' => 'nom', 'uns' => 'dat|acc');
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 1, 'number' => 'plur', 'case' => $case{$lcform}});
            }
            elsif($lemma eq 'du')
            {
                my %case = ('du' => 'nom', 'dir' => 'dat', 'dich' => 'acc');
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 2, 'number' => 'sing', 'politeness' => 'inf', 'case' => $case{$lcform}});
            }
            elsif($lemma eq 'ihr' && $node->is_pronoun())
            {
                my %case = ('ihr' => 'nom', 'euch' => 'dat|acc');
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 2, 'number' => 'plur', 'politeness' => 'inf', 'case' => $case{$lcform}});
            }
            elsif($lemma eq 'ihr' && $node->is_determiner())
            {
                # It can mean either "her" or "their".
                $iset->set_hash({'pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3});
                $stts = 'PPOSAT';
                $node->set_conll_pos($stts);
            }
            elsif($lemma eq 'er')
            {
                my %case = ('er' => 'nom', 'ihm' => 'dat', 'ihn' => 'acc');
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 3, 'number' => 'sing', 'gender' => 'masc', 'case' => $case{$lcform}});
            }
            elsif($lemma eq 'es')
            {
                my %case = ('es' => 'nom|acc', "'s" => 'nom|acc', 'ihm' => 'dat');
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 3, 'number' => 'sing', 'gender' => 'neut', 'case' => $case{$lcform}});
            }
            # For strange reasons, capitalized "Ihm" has the lemma "er|er|es".
            elsif($lemma eq 'er|er|es')
            {
                $lemma = 'er|es';
                $node->set_lemma($lemma);
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 3, 'number' => 'sing', 'gender' => 'masc|neut', 'case' => 'dat'});
            }
            elsif($lemma eq 'sie')
            {
                # Either singular feminine ("she"), or plural any gender ("they"). The lemma does not change.
                # Try to disambiguate based on the form of the governing finite verb.
                my $fv = $self->get_parent_finite_verb($node);
                if($lcform eq 'ihnen' || defined($fv) && lc($fv->form()) =~ m/(^sind|n)$/)
                {
                    my %case = ('sie' => 'nom|acc', 'ihnen' => 'dat');
                    $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 3, 'number' => 'plur', 'case' => $case{$lcform}});
                }
                else
                {
                    my %case = ('sie' => 'nom|acc', 'ihr' => 'dat');
                    $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 3, 'number' => 'sing', 'gender' => 'fem', 'case' => $case{$lcform}});
                }
            }
            elsif($lemma eq 'Sie|sie')
            {
                # Usually polite 2nd person any number (semantically; formally it is 3rd person).
                # But it could also be the above (normal 3rd person), capitalized because of sentence start.
                my %case = ('Sie' => 'nom|acc', 'Ihnen' => 'dat');
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 2, 'politeness' => 'pol', 'case' => $case{$form}});
            }
            elsif($lemma eq 'er|es|sie') # reflexive "sich"
            {
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => $reflex, 'person' => 3, 'case' => 'dat|acc'});
            }
        }
        elsif($node->is_pronominal())
        {
            # We do not want to change pos because we do not want to change PRON <--> DET at this stage.
            my $pos = $iset->pos();
            # Possessive pronouns.
            if($stts eq 'PPOSAT')
            {
                if($lemma eq 'mein')
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'possnumber' => 'sing'});
                }
                elsif($lemma eq 'dein')
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => 2, 'politeness' => 'inf', 'possnumber' => 'sing'});
                }
                elsif($lemma eq 'sein')
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3, 'possnumber' => 'sing', 'possgender' => 'masc|neut'});
                }
                elsif($lemma eq 'ihr')
                {
                    # It can mean either "her" or "their".
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => 3});
                }
                elsif($lemma eq 'unser')
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'possnumber' => 'plur'});
                }
                elsif($lemma eq 'euer')
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => 2, 'politeness' => 'inf', 'possnumber' => 'plur'});
                }
                elsif($lemma eq 'Ihr|ihr')
                {
                    # It can mean either polite "your" (anywhere), or "her" or "their" (at sentence start or else where capitalization is required).
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => '2|3'});
                }
            }
            elsif($stts =~ m/^PD(S|AT)$/)
            {
                # We have already solved "der, die, das" above.
                # PDS dies
                # PDAT dies derselbe selb diejenige
                $iset->set_hash({'pos' => $pos, 'prontype' => 'dem'});
            }
            elsif($stts =~ m/^PW(S|AT)$/)
            {
                # PWS wer was welch
                # PWAT welch wieviel
                $iset->set_hash({'pos' => $pos, 'prontype' => 'int'});
                if($lemma =~ m/^(wer|was)$/)
                {
                    $iset->set('number', 'sing');
                }
            }
            elsif($stts =~ m/^PREL(S|AT)$/)
            {
                # PRELS was
                $iset->set_hash({'pos' => $pos, 'prontype' => 'rel'});
                if($lemma =~ m/^(wer|was)$/)
                {
                    $iset->set('number', 'sing');
                }
            }
            elsif($stts =~ m/^PI(S|AT)$/)
            {
                # PIAT alle jed kein keinerlei beide ein was einiges einige solch meist mehr viel paar mehrere
                # PIS man jemand alle nix ander wenig etwas nichts
                if($lemma =~ m/^(niemand|nichts|nix)$/)
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'neg', 'number' => 'sing'});
                }
                elsif($lemma =~ m/^(kein|keinerlei)$/)
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'neg'});
                }
                elsif($lemma =~ m/^(alle|jed)$/)
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'tot'});
                }
                elsif($lemma eq 'beide')
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'tot', 'numtype' => 'card'});
                }
                else
                {
                    $iset->set_hash({'pos' => $pos, 'prontype' => 'ind'});
                }
            }
            # Some words have manual UPOS PRON but their predicted XPOS is not pronominal.
            # "mit" = "with" is a preposition (PRON PTKVZ) but this case is typo, it should read "mir" and mean "me"
            elsif($stts eq 'PTKVZ' and $lemma eq 'mit')
            {
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'person' => 1, 'number' => 'sing', 'case' => 'dat', 'typo' => 'typo'});
                $lemma = 'ich';
                $node->set_lemma($lemma);
                $stts = 'PPER';
                $node->set_conll_pos($stts);
            }
            # "in" = "in" is a preposition (PRON APPR) but these cases are typos, they should read "ihn" and mean "him"
            elsif($stts eq 'APPR' and $lemma eq 'in')
            {
                $iset->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'person' => 3, 'number' => 'sing', 'gender' => 'masc', 'case' => 'acc', 'typo' => 'typo'});
                $lemma = 'er';
                $node->set_lemma($lemma);
                $stts = 'PPER';
                $node->set_conll_pos($stts);
            }
            elsif($lemma eq 'meinen') # "meine", "meinen" tagged PRON VVFIN, mistaken for the verb "meinen" = "to mean"
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'prs', 'poss' => 'poss', 'person' => 1, 'possnumber' => 'sing'});
                $lemma = 'mein';
                $node->set_lemma($lemma);
                $stts = 'PPOSAT';
                $node->set_conll_pos($stts);
            }
            # "ebendieses" = "right this" (PRON ADV)
            elsif($lemma eq 'ebendieses')
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'dem'});
                $lemma = 'ebendies';
                $node->set_lemma($lemma);
                $stts = 'PDAT';
                $node->set_conll_pos($stts);
            }
            # "selbst" = "self" (PRON ADV)
            elsif($lemma eq 'selbst')
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'dem', 'reflex' => 'reflex'});
            }
            # "etwas" = "something" (PRON ADV)
            # "irgendetwas" = "something" (PRON ADV)
            elsif($lemma =~ m/^(etwas|irgendetwas)$/)
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'ind'});
                $stts = 'PIS';
                $node->set_conll_pos($stts);
            }
            # "anderer" = "other" (tagged PRON ADJA, i.e. adjective)
            # "eigige" is typo, should be "einige" = "some" (PRON ADJA)
            # "genug" = "enough" (PRON ADV)
            # "mehr" = "more" (PRON ADV)
            # "soviel" = "so much" (PRON ADV)
            # "viel" = "much" (PRON ADV)
            # "wenig" = "little" (PRON ADV)
            # "weniger" = "less" (PRON ADV)
            # "zahlreich" = "numerous" (PRON ADJA)
            elsif($lemma =~ m/^(ander|eigige|genug|mehr|soviel|viel|wenig(er)?|zahlreich)$/)
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'ind'});
                $stts = 'PIAT';
                $node->set_conll_pos($stts);
            }
            # "einen" (PRON ADJA)
            elsif($lemma eq 'einen')
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'ind'});
                $lemma = 'ein';
                $node->set_lemma($lemma);
                $stts = 'PIAT';
                $node->set_conll_pos($stts);
            }
            # "mehren" (PRON VVFIN)
            elsif($lemma eq 'mehren')
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'ind'});
                $lemma = 'mehr';
                $node->set_lemma($lemma);
                $stts = 'PIAT';
                $node->set_conll_pos($stts);
            }
            # "keinster" = "no" (PRON ADJA)
            elsif($lemma eq 'keinster')
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'neg'});
                $stts = 'PIAT';
                $node->set_conll_pos($stts);
            }
            # "sämtlich" = "all, entire" (PRON ADJA)
            elsif($lemma eq 'sämtlich')
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'tot'});
                $stts = 'PIAT';
                $node->set_conll_pos($stts);
            }
            # "warum" = "why" (PRON PWAV)
            # "wie" = "how" (PRON PWAV) ... we must check PWAV here because it could be also conjunction "as"
            # "wo" = "where" (PRON PWAV)
            elsif($lemma =~ m/^(warum|wie|wo)$/ && $stts eq 'PWAV')
            {
                $iset->set_hash({'pos' => 'adv', 'prontype' => 'int'});
            }
            # "da" + preposition can be demonstrative or relative pronouns or adverbs (PRON PAV)
            # examples: dadurch, dafür, damit, danach, darauf, darin, darüber, darum, davon, dazu
            elsif($stts eq 'PAV' && $lemma =~ m/^da/)
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'dem|rel'});
            }
            # "wo" + preposition can be interrogative or relative pronouns or adverbs (PRON PWAV)
            # examples: wodurch, womit, wonach, worauf, worüber, wovon, wozu
            elsif($stts eq 'PWAV' && $lemma =~ m/^wo/)
            {
                $iset->set_hash({'pos' => $pos, 'prontype' => 'int|rel'});
            }
            # nouns (tagging errors): Auszug, Männchen
            elsif($stts eq 'NN')
            {
                $iset->set_hash({'pos' => 'noun', 'nountype' => 'com'});
            }
            elsif($stts eq 'NE')
            {
                $iset->set_hash({'pos' => 'noun', 'nountype' => 'prop'});
            }
            # adjectives: erster, zweiter, weiterer, letzter, gleicher etc.
            elsif($stts eq 'ADJA')
            {
                my $numtype = $lemma =~ m/^(erst|zweit)$/ ? 'ord' : '';
                $iset->set_hash({'pos' => 'adj', 'numtype' => $numtype});
            }
            # "heraus" = "out" (PRON ADV)
            # "so" = "so" (DET ADV in "so ein")
            elsif($lemma =~ m/^(heraus|so)$/)
            {
                $iset->set_hash({'pos' => 'adv'});
            }
            # "an" = "at" is a preposition (DET APPR)
            elsif($stts eq 'APPR')
            {
                $iset->set_hash({'pos' => 'adp'});
            }
            # "dass" = "that" is a subordinating conjunction (PRON KOUS)
            # "wie" = "as" can be also comparative conjunction (PRON KOKOM) but the two occurrences should be KOUS and ADV ("how")
            elsif($stts =~ m/^(KOUS|KOKOM)$/)
            {
                $iset->set_hash({'pos' => 'conj', 'conjtype' => 'sub'});
            }
            # "nicht" = "not" is a negative particle (PRON PTKNEG)
            elsif($stts eq 'PTKNEG')
            {
                $iset->set_hash({'pos' => 'part', 'negativeness' => 'neg'});
            }
            # Foreign pronouns and determiners should not get the PRON/DET tag.
            # Examples: I, you, what, the
            # "we" is tagged PRON VVFIN
            elsif($stts eq 'FM' || $lemma eq 'we')
            {
                $iset->set_hash({'foreign' => 'foreign'});
            }
        }
        # Mark ordinal numerals (they are plain adjectives at the moment).
        # Note that we have to check whether it is adjective because the cardinal and ordinal eight share the lemma "acht".
        # We do not support all possible compounds such as "einhundertdreiundzwanzigst".
        # We cannot allow anything at the beginning because we do not want to match things like äußerst, schweizweit, motiviert, gemacht.
        if($node->is_adjective() && $lemma =~ m/^(erst|zweit|dritt|viert|fünft|sechst|sieb(en)?t|acht|neunt|(drei|vier|fünf|sech|sieb|acht|neun)?zehnt|elft|zwölft|zwanzigst|drei(ß|ss)igst|vierzigst|fünfzigst|sechzigst|siebzigst|achtzigst|neunzigst|(ein|zwei|drei|vier|fünf|sechs|sieben|acht|neun)?hundertst|tausendst|millionst)$/)
        {
            $iset->set('numtype', 'ord');
        }
        # Case of noun phrases: manual relation labels sometimes help.
        if(($node->is_noun() || $node->is_adjective()))
        {
            my $deprel = $node->deprel();
            my @children = $node->children();
            my @casechildren = grep {$_->deprel() eq 'case'} (@children);
            my @detchildren = grep {$_->deprel() eq 'det'} (@children);
            my $det = ''; # we want to query it even if we don't know it
            my $case = undef;
            # Cluster determiners according to gender, number and case:
            # der,               dieser ... masc sing nom, fem sing gen|dat, plur gen
            #      ein,   ihr           ... masc sing nom, neut sing nom|acc
            #      einer, ihrer         ... fem sing gen|dat, plur gen
            # das                       ... neut sing nom|acc
            # des, eines, ihres         ... masc|neut sing gen
            #                    dieses ... masc sing gen, neut sing nom|gen|acc
            # dem, einem, ihrem, diesem ... masc|neut sing dat
            # den, einen, ihren, diesen ... masc sing acc, plur dat
            # die, eine,  ihre,  diese  ... fem sing nom|acc, plur nom|acc
            if(scalar(@detchildren)>0)
            {
                my $lcdetform = lc($detchildren[0]->form());
                if($lcdetform =~ m/(der|dieser|jeder|jener|cher)$/)
                {
                    $det = 'der';
                }
                elsif($lcdetform =~ m/(ein|ihr|unser|euer)$/)
                {
                    $det = 'ein';
                }
                elsif($lcdetform =~ m/r$/)
                {
                    $det = 'einer';
                }
                elsif($lcdetform =~ m/^(das|dieses)$/)
                {
                    $det = $lcdetform;
                }
                elsif($lcdetform =~ m/s$/)
                {
                    $det = 'des';
                }
                elsif($lcdetform =~ m/m$/)
                {
                    $det = 'dem';
                }
                elsif($lcdetform =~ m/n$/)
                {
                    $det = 'den';
                }
                elsif($lcdetform =~ m/e$/)
                {
                    $det = 'die';
                }
            }
            # Subject is nominative.
            if($deprel =~ m/^nsubj(pass)?$/)
            {
                $case = 'nom';
            }
            # Indirect object is dative.
            elsif($deprel eq 'iobj')
            {
                $case = 'dat';
            }
            # Direct object is accusative.
            elsif($deprel eq 'dobj')
            {
                $case = 'acc';
            }
            # Modifier with certain preposition is genitive.
            elsif($deprel eq 'nmod' && scalar(@casechildren)>0 && $casechildren[0]->lemma() =~ m/^(angesichts|(an)?statt|(au(ß|ss)|inn)erhalb|(dies|jen)seits|dank|infolge|inmitten|mittels|seitens|trotz|(ober|unter)halb|unweit|während|wegen|längst|zugunsten)$/)
            {
                $case = 'gen';
            }
            # Modifier with certain preposition is dative.
            elsif($deprel eq 'nmod' && scalar(@casechildren)>0 && $casechildren[0]->lemma() =~ m/^(aus|bei|mit|nach|von|zu)$/)
            {
                $case = 'dat';
            }
            # Modifier with certain preposition is accusative.
            elsif($deprel eq 'nmod' && scalar(@casechildren)>0 && $casechildren[0]->lemma() =~ m/^(durch|für|gegen|ohne|um)$/)
            {
                $case = 'acc';
            }
            # Certain prepositions are either dative (location) or accusative (direction).
            elsif($deprel eq 'nmod' && scalar(@casechildren)>0 && $casechildren[0]->lemma() =~ m/^(an|auf|hinter|in|neben|über|unter|vor|zwischen)$/)
            {
                # dat: dem der den einer
                # acc: den die das ein dieses
                if(scalar(@detchildren)>0)
                {
                    if($det =~ m/^(dem|der|einer)$/)
                    {
                        $case = 'dat';
                    }
                    elsif($det =~ m/^(die|das|ein|dieses)$/)
                    {
                        $case = 'acc';
                    }
                    # "den" is accusative singular or dative plural.
                    # If form = lemma, assume singular.
                    elsif($det eq 'den')
                    {
                        $case = $lcform eq lc($lemma) ? 'acc' : 'dat';
                    }
                }
            }
            # Modifier without preposition is probably nominative or genitive.
            # Dative and accusative probably cannot be excluded, they could occur with verbal nouns and participles.
            elsif($deprel eq 'nmod' && scalar(@casechildren)==0)
            {
                # nom: der die das ein dieses
                # gen: des dieses der einer
                # "der" is nominative masculine singular, genitive feminine singular, or genitive plural.
                # We do not know the gender and cannot distinguish masculine from feminine.
                if($det =~ m/^(des|einer)$/)
                {
                    $case = 'gen';
                }
            }
            if(defined($case))
            {
                $iset->set('case', $case);
                # Case inflections of nouns are rare except for the genitive of masculines and neuters (der Tag – des Tages).
                # Hence if the case is not genitive and the form differs from lemma, assume it's plural (der Tag – die Tage).
                # Note that this may occasionally cause errors, e.g. dative of Wald can be (besides Wald) also Walde, even if it is rarely used.
                # Occurred: "dem Kunden", dative of "der Kunde". ###!!! We should check the determiner too!
                # Sometimes the form does not change although it is plural ###!!! seine Schnäppchen!
                # Also note that this only works for nouns, not pronouns, adjectives or determiners!
                my $number = undef;
                my $gender = undef;
                if($node->is_noun() && !$node->is_pronoun())
                {
                    # sing: der des dem den die das ein einer dieses
                    # plur: die der den die einer
                    my $same = $lcform eq lc($lemma);
                    if($case eq 'nom' && $same ||
                       $case eq 'gen' && ($det =~ m/^(des|dieses)$/ || $same && $det =~ m/^(der|einer)$/) ||
                       $case eq 'dat' && ($det =~ m/^(dem|der|einer)$/ || $same && $det ne 'den') ||
                       $case eq 'acc' && $same)
                    {
                        $number = 'sing';
                    }
                    else
                    {
                        $number = 'plur';
                    }
                    if(defined($number))
                    {
                        $iset->set('number', $number);
                        # If we have a determiner and the form is singular, we can also detect the gender.
                        # masc: der des dem den ein dieses
                        # neut: das des dem ein dieses
                        # fem:  die der einer
                        if($number eq 'sing')
                        {
                            if($case eq 'nom' && $det eq 'der' || $det eq 'den')
                            {
                                $gender = 'masc';
                            }
                            elsif($det eq 'das' || $case eq 'nom' && $det eq 'dieses')
                            {
                                $gender = 'neut';
                            }
                            elsif($det =~ m/^(des|dem|ein|dieses)$/)
                            {
                                $gender = 'masc|neut';
                            }
                            elsif($det =~ m/^(die|der|einer)$/)
                            {
                                $gender = 'fem';
                            }
                            $iset->set('gender', $gender) if(defined($gender));
                        }
                    }
                    if(!defined($gender))
                    {
                        if($lemma =~ m/(ast|ich|ig|or|us)$/)
                        {
                            $gender = 'masc';
                        }
                        elsif($lemma =~ m/(ei|enz|heit|ie|keit|schaft|sion|sis|tät|tion|ung)$/)
                        {
                            $gender = 'fem';
                        }
                        elsif($lemma =~ m/(chen|lein|il|it|ment|um)$/)
                        {
                            $gender = 'neut';
                        }
                        $iset->set('gender', $gender) if(defined($gender));
                    }
                }
                # Dependent determiners and adjectives agree in gender, number and case.
                # Even if we knew gender of a plural noun, we should not propagate gender to plural determiners and adjectives because they do not inflect for it in plural.
                foreach my $child (@children)
                {
                    if($child->deprel() =~ m/^(det|amod)/)
                    {
                        $child->iset()->set('gender', $gender) if(defined($gender));
                        $child->iset()->set('number', $number) if(defined($number));
                        $child->iset()->set('case', $case);
                    }
                }
            }
        }
        # Degree of comparison of adjectives.
        if($node->is_adjective() && !$node->is_pronominal())
        {
            # We need to eliminate the sharp s to increase the chance of finding a match.
            $lcform =~ s/ß/ss/g;
            $lemma =~ s/ß/ss/g;
            my $degree = '';
            # lemma e.g. schnell
            # pos: schnell schnelle schnelles schnellem schnellen schneller
            # cmp: schneller schnellere schnelleres schnellerem schnelleren schnellerer
            # sup: schnellst (but breitEst) schnellste schnellstes schnellstem schnellsten schnellster
            ###!!! We will not catch adjectives where the stem vowel changes, e.g. nah – näher – nächst.
            if($lcform =~ m/^$lemma(e|es|em|en)?$/) ###!!! "-er" is ambiguous
            {
                $degree = 'pos';
            }
            elsif($lcform =~ m/^$lemma(er)$/)
            {
                # Positive: "ein einzigartiger Parfümeur"; "sehr guter Service" (indefinite masc sing nom)
                # Also positive: "in letzter Zeit" (indefinite fem sing dat)
                # Comparative: "sind die deutlichr schlechter"
                # We may want to nail down these cases by other evidence, e.g. the gender and number of the noun phrase.
                $degree = 'pos|cmp';
            }
            elsif($lcform =~ m/^$lemma(ere|eres|erem|eren|erer)$/ || $lcform =~ m/^(besser)(e|es|em|en|er)?$/)
            {
                $degree = 'cmp';
            }
            elsif($lcform =~ m/^$lemma(e)?st(e|es|em|en|er)?$/ || $lcform =~ m/^(best)(e|es|em|en|er)?$/)
            {
                $degree = 'sup';
            }
            if($degree ne '')
            {
                $iset->set('degree', $degree);
            }
        }
        # Fix postpositions and circumpositions that the tagger mistook for separable verb prefixes.
        if($stts eq 'PTKVZ' && $node->deprel() eq 'case')
        {
            # It probably does not precede the parent noun but if it does, it is a preposition.
            my $ordadp = $node->ord();
            my $ordnoun = $node->parent()->ord();
            if($ordadp < $ordnoun)
            {
                $stts = 'APPR';
            }
            else
            {
                # If there is another case dependent before the noun, the case dependents together form a circumposition.
                my $prep = any {$_->deprel() eq 'case' && $_->ord() < $ordnoun} ($node->parent()->children());
                if($prep)
                {
                    $stts = 'APZR';
                }
                else
                {
                    $stts = 'APPO';
                }
            }
            $node->set_conll_pos($stts);
        }
    }
    # Person and number of finite verbs can be deduced from their subjects.
    # We have to do this in a separate loop, after all the pronouns have been solved.
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $lcform = lc($node->form());
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        if($node->is_finite_verb())
        {
            my $subject = $self->get_subject($node);
            if(defined($subject))
            {
                my $number = $subject->iset()->number();
                my $person = $subject->iset()->person();
                # Note that the polite pronoun "Sie" is tagged with 2nd person but the verb is third person plural.
                # Also note that we will occasionally introduce errors if there is a coordination of singular subjects, the verb is plural.
                if($lcform =~ m/en$/)
                {
                    $iset->set('number', 'plur');
                }
                elsif($lcform =~ m/e$/)
                {
                    $iset->set('number', 'sing');
                }
                elsif($number =~ m/^(sing|plur)$/)
                {
                    $iset->set('number', $number);
                }
                if($person eq '1' || $person eq '2' && $subject->iset()->politeness() eq 'inf')
                {
                    $iset->set('person', $person);
                }
                else
                {
                    $iset->set('person', '3');
                }
            }
            # Mood and tense can be derived only from the lexicon. Set it at least for a few high-frequency verbs.
            # Note that the imperative is usually ambiguous with indicative or subjunctive and we could only distinguish it by context and word order.
            # Certain forms of subjunctive I are usually ambiguous with indicative.
            # sein "to be"
            # mood=ind tense=pres: bin bist ist sind seid
            # mood=ind tense=past: war warst waren wart
            # mood=imp:            sei seien seid
            # mood=sub (Konj I):   sei seist seiest seien seit seiet
            # mood=sub (Konj II):  wäre wärst wärest wären wärt wäret
            # haben "to have"
            # mood=ind tense=pres: habe hab hast hat haben habt
            # mood=ind tense=past: hatte hattest hatten hattet
            # mood=imp:            habe hab haben habt
            # mood=sub (Konj I):   habe habest haben habet
            # mood=sub (Konj II):  hätte hättest hätten hättet
            # werden "to become"
            # mood=ind tense=pres: werde wirst wird werden werdet
            # mood=ind tense=past: wurde wurdest wurden wurdet
            # mood=imp:            werde werden werdet
            # mood=sub (Konj I):   werde werdest werden werdet
            # mood=sub (Konj II):  würde würdest würden würdet
            # können "can"
            # mood=ind tense=pres: kann kannst können könnt
            # mood=ind tense=past: konnte konntest konnten konntet
            # mood=sub tense=pres: könne könnest können könnet
            # mood=sub tense=past: könnte könntest könnten könntet
            # müssen "must"
            # mood=ind tense=pres: muss musst müssen müsst
            # mood=ind tense=past: musste musstest mussten musstet
            # mood=sub tense=pres: müsse müssest müssen müsset
            # mood=sub tense=past: müsste müsstest müssten müsstet
            if($lcform =~ m/^(bin|bist|ist|sind|seid|ha(be|st|t|ben|bt)|werd(e|en|et)|wir(st|d)|kann(st)?|könn(en|t)|musst?|müss(en|t)|soll(st|en|t)?|will(st)?|woll(en|t)|mag(st)?|mög(en|t)|darf(st)?|dürf(en|t)|weiß(t)?|wiss(en|t))$/)
            {
                $iset->add('mood' => 'ind', 'tense' => 'pres');
            }
            elsif($lcform =~ m/^((war|wurde)(st|en|t)?|(hat|konn|muss|[sw]oll|moch|durf|wuss)(te|test|ten|tet))$/)
            {
                $iset->add('mood' => 'ind', 'tense' => 'past');
            }
            elsif($lcform =~ m/^(sei(e?st|en|e?t)|(hab|werd|könn|müss|[sw]oll|mög|dürf|wiss)(e|est|en|et))$/)
            {
                $iset->add('mood' => 'sub', 'tense' => 'pres');
            }
            elsif($lcform =~ m/^(wär(e|e?st|en|e?t)|würde(st|en|t)?|(hät|könn|müss|möch|dürf|wüss)(te|test|ten|tet))$/)
            {
                $iset->add('mood' => 'sub', 'tense' => 'past');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Identifies and returns the finite verb governing a node. If the parent is
# not a finite verb, looks for auxiliary/copula siblings.
#------------------------------------------------------------------------------
sub get_parent_finite_verb
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    return $parent if($parent->is_finite_verb());
    my @siblings = grep {$_ != $node} $parent->children();
    # Note that there may be other finite siblings that we are not interested in, such as subordinate predicates.
    my @result = grep {$_->deprel() =~ m/^(aux|auxpass|cop)$/ && $_->is_finite_verb()} @siblings;
    my $result = scalar(@result) >= 1 ? $result[0] : undef;
    return $result;
}



#------------------------------------------------------------------------------
# Identifies and returns the subject of a verb or another predicate. If the
# verb is copula or auxiliary, finds the subject of its parent.
#------------------------------------------------------------------------------
sub get_subject
{
    my $self = shift;
    my $node = shift;
    my @subj = grep {$_->deprel() =~ m/subj/} $node->children();
    # There should not be more than one subject (coordination is annotated differently).
    # The caller expects at most one node, so we will not return more than that, even if present.
    return $subj[0] if(scalar(@subj)>0);
    return undef if($node->is_root());
    return $self->get_subject($node->parent()) if($node->deprel() =~ m/^(aux|cop)/);
    return undef;
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
# Unifies the relations of possessive determiners to det:poss. Before the fix,
# some were nmod:poss and some were just det.
#------------------------------------------------------------------------------
sub fix_possessive_determiners
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        # Exclude nodes that have children, e.g. prepositions. They are probably not determiners.
        # Either there is a tagging error (in "kam zu ihr", "ihr" is not possessive, it is the dative case of "sie"),
        # or there is ellipsis and the possessive pronoun has been promoted to the place of the elided noun.
        if($node->lemma() =~ m/^(mein|dein|sein|Ihr\|ihr|ihr|unser|euer)$/ && $node->is_possessive() && $node->deprel() =~ m/(nmod:poss|det)/ && $node->is_leaf())
        {
            $node->set_deprel('det:poss');
        }
    }
}



#------------------------------------------------------------------------------
# Infinitive-marking "zu" is currently tagged PART and attached as aux. The tag
# is OK (English "to" and Swedish "att" are also particle when used to mark
# the infinitive; but Dutch "te" is tagged ADP). The relation is not OK. It
# should be "mark".
#------------------------------------------------------------------------------
sub fix_infinitival_zu
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        if($node->form() =~ m/^zu$/i && $parent->is_verb() && $node->deprel() =~ m/^aux/)
        {
            $node->set_deprel('mark');
        }
    }
}



#------------------------------------------------------------------------------
# Separable verb prefixes are currently attached to the verb as mark. That
# differs from the other Germanic languages where they are attached as
# compound:prt. Fix it and make it "compound:prt", too (relying on the
# predicted STTS tags to identify the verb prefixes correctly).
#------------------------------------------------------------------------------
sub fix_separable_verb_prefixes
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'mark' && $node->conll_pos() eq 'PTKVZ')
        {
            $node->set_deprel('compound:prt');
        }
    }
}



#------------------------------------------------------------------------------
# Sometimes the "mwe" relation connects a multi-word expression to its parent,
# instead of connecting the members of the MWE together. We can only fix it by
# consulting a list of potentially offending MWEs. For some of them we will not
# even grant them the MWE status, as this should be very restricted in UD.
#------------------------------------------------------------------------------
sub fix_mwe
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        # Alles in Allem
        if($node->form() =~ m/^alles$/i && $self->get_node_spanstring($node) =~ m/^alles in allem$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # Make sure that the structure is nmod(Alles, Allem); case(Allem, in).
            $subtree[2]->set_parent($node);
            $subtree[2]->set_deprel('nmod');
            $subtree[1]->set_parent($subtree[2]);
            $subtree[1]->set_deprel('case');
            # The relation to the parent of the MWE should be nmod (because "Alles" is pronoun), not mwe.
            $node->set_deprel('nmod');
        }
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

=item Treex::Block::HamleDT::DE::FixUD

This is a temporary block that should fix selected known problems in the German UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

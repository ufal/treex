package Treex::Block::HamleDT::AR::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Base'; # provides get_node_spanstring()



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        $self->fix_morphology($node);
    }
    # Do not call syntactic fixes from the previous loop. First make sure that
    # all nodes have correct morphology, then do syntax (so that you can rely
    # on the morphology you see at the parent node).
    foreach my $node (@nodes)
    {
        $self->fix_constructions($node);
        $self->fix_annotation_errors($node);
    }
    $self->fix_fixed_expressions($root);
    ###!!! dissolving fixed with gaps may cause other errors, e.g. an ADJ being attached as case
    ###!!!$self->fix_fixed_expressions_with_gaps($root);
    # Certain node types are supposed to be leaves. If they have children, we
    # will raise the children. However, we can only do it after we have fixed
    # all deprels, thus it cannot be included in fix_constructions() above.
    foreach my $node (@nodes)
    {
        $self->fix_leaves($node);
    }
    foreach my $node (@nodes)
    {
        $self->identify_acl_relcl($node);
    }
    # It is possible that we changed the form of a multi-word token.
    # Therefore we must re-generate the sentence text.
    #$root->get_zone()->set_sentence($root->collect_sentence_text());
    # Because of the changes made above, we may have created new instances where
    # an "obl" is attached under something that is clearly a nominal, therefore
    # the relation should be "nmod".
    $self->check_obl_under_nominal($root);
}



#------------------------------------------------------------------------------
# Fixes known issues in part-of-speech and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $node = shift;
    my $lform = lc($node->form());
    my $lemma = $node->lemma();
    my $iset = $node->iset();
    my $deprel = $node->deprel();
    # These are symbols, not punctuation.
    if($lform =~ m/^[<>]$/)
    {
        $iset->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
    }
    # Make sure that the UPOS tag still matches Interset features.
    $node->set_tag($node->iset()->get_upos());
}



#------------------------------------------------------------------------------
# Figures out whether an adnominal clause is a relative clause, and changes the
# relation accordingly.
#------------------------------------------------------------------------------
sub identify_acl_relcl
{
    my $self = shift;
    my $node = shift;
    return unless($node->deprel() =~ m/^acl(:|$)/);
    # Look for a relative pronoun or a subordinating conjunction. The first
    # such word from the left is the one that matters. However, it is not
    # necessarily the first word in the subtree: there can be punctuation and
    # preposition. The relative pronoun can be even the root of the clause,
    # i.e., the current node, if the clause is copular.
    # Specifying (first|last|preceding|following)_only implies ordered.
    my @subordinators = grep {$_->is_subordinator() || $_->is_relative()} ($node->get_descendants({'preceding_only' => 1, 'add_self' => 1}));
    return unless(scalar(@subordinators) > 0);
    my $subordinator = $subordinators[0];
    # If there is a subordinating conjunction, the clause is not relative even
    # if there is later also a relative pronoun.
    return if($subordinator->is_subordinator() || $subordinator->deprel() =~ m/^mark(:|$)/);
    # The relative words are expected only with certain grammatical relations.
    # The acceptable relations vary depending on the depth of the relative word.
    # In depth 0, the relation is acl, which is not acceptable anywhere deeper.
    my $depth = 0;
    for(my $i = $subordinator; $i != $node; $i = $i->parent())
    {
        $depth++;
    }
    # PADT currently contains only forms of one relative pronoun: اَلَّذِي allaḏī "that, which"
    return if($depth > 0 && $subordinator->lemma() =~ m/^(اَلَّذِي)$/ && $subordinator->deprel() !~ m/^(nsubj|obj|iobj|obl|nmod|det)(:|$)/);
    $node->set_deprel('acl:relcl');
}



#------------------------------------------------------------------------------
# Fixes dependency relations (tree topology or labels or both).
#------------------------------------------------------------------------------
sub fix_constructions
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $deprel = $node->deprel();
    # Noun cannot be copula. Some pronouns can be copulas but then they cannot have children.
    if(($node->is_noun() && !$node->is_pronoun() ||
        $node->is_pronoun() && !$node->is_leaf) && $deprel =~ m/^cop(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Neither noun nor pronoun can be auxiliary verb, case marker, subordinator, coordinator, adverbial modifier.
    elsif($node->is_noun() && $deprel =~ m/^(nummod|aux|case|mark|cc|advmod|punct)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Adjective cannot be auxiliary, copula, case, mark, cc.
    elsif($node->is_adjective() && !$node->is_pronominal() && $deprel =~ m/^(aux|cop|case|mark|cc)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'amod';
        }
        else
        {
            $deprel = 'advmod';
        }
        $node->set_deprel($deprel);
    }
    # Pronoun cannot be nummod.
    elsif($node->is_pronoun() && $deprel =~ m/^nummod(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Some determiners could be copulas but then they cannot have children.
    # Also, if the following are labeled as copulas, it is wrong:
    # مَن = man = who
    # مَا = mā = what, which
    elsif($node->is_determiner() && (!$node->is_leaf() || $node->lemma() =~ m/^(مَن|مَا)$/) && $deprel =~ m/^cop(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'det';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Determiner cannot be aux, advmod, case, mark, cc.
    elsif($node->is_determiner() && $deprel =~ m/^(aux|advmod|case|mark|cc)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'det';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Cardinal numeral cannot be aux, copula, case, mark, cc.
    elsif($node->is_numeral() && $deprel =~ m/^(aux|cop|case|mark|cc)(:|$)/)
    {
        $deprel = 'nummod';
        $node->set_deprel($deprel);
    }
    # Verb cannot be advmod.
    elsif($node->is_verb() && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'advcl';
        $node->set_deprel($deprel);
    }
    # Verb should not be case, mark, cc.
    elsif($node->is_verb() && $deprel =~ m/^(case|mark|cc)(:|$)/)
    {
        $deprel = 'parataxis';
        $node->set_deprel($deprel);
    }
    # Adverb cannot be copula.
    elsif($node->is_adverb() && $deprel =~ m/^(cop|aux)(:|$)/)
    {
        $deprel = 'advmod';
        $node->set_deprel($deprel);
    }
    # Preposition cannot be advmod. It could be oblique dependent if it is a
    # promoted orphan of a noun phrase. Or it is an annotation error and a
    # prepositional phrase stayed mistakenly headed by the preposition.
    elsif($node->is_adposition() && $deprel =~ m/^advmod(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Preposition cannot be copula.
    elsif(($node->is_adposition() || $node->is_particle()) && $deprel =~ m/^cop(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'case';
        }
        else
        {
            $deprel = 'mark';
        }
        $node->set_deprel($deprel);
    }
    # Subordinating conjunction cannot be adverbial modifier.
    elsif($node->is_subordinator() && $deprel =~ m/^advmod(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'case';
        }
        else
        {
            $deprel = 'mark';
        }
        $node->set_deprel($deprel);
    }
    # Conjunction cannot be copula, punctuation.
    elsif($node->is_conjunction() && $deprel =~ m/^(aux|cop|punct)(:|$)/)
    {
        $deprel = 'cc';
        $node->set_deprel($deprel);
    }
    # Some particles (e.g., "الا") are attached as aux or aux:pass and have children, which is inacceptable.
    elsif($node->is_particle() && !$node->is_leaf() && $deprel =~ m/^(aux|cop)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Other particles are leaves, are correctly attached as aux but should also be tagged AUX.
    elsif($node->is_particle() && $node->is_leaf() && $deprel =~ m/^aux(:|$)/)
    {
        $node->set_tag('AUX');
        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux'});
    }
    # Interjection cannot be auxiliary.
    elsif($node->is_interjection() && $deprel =~ m/^(cop|aux)(:|$)/)
    {
        $deprel = 'discourse';
        $node->set_deprel($deprel);
    }
    # If we changed tag of a symbol from PUNCT to SYM above, we must also change
    # its dependency relation.
    elsif($node->is_symbol() && $deprel =~ m/^punct(:|$)/ &&
          $node->ord() > $parent->ord())
    {
        $deprel = 'flat';
        $node->set_deprel($deprel);
    }
    elsif($node->is_symbol() && $deprel =~ m/^punct(:|$)/)
    {
        $deprel = 'dep';
        $node->set_deprel($deprel);
    }
    # Unknown part of speech ('X') cannot be copula. One example that I saw was
    # an out-of-vocabulary proper noun but I do not know what the others are.
    elsif($node->iset()->pos() eq '' && $deprel =~ m/^(aux|cop)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # There are some strange cases of right-to-left apposition. I do not
    # understand what is going on there and what should be the remedy. This is
    # just a temporary hack to silence the validator.
    elsif($deprel =~ m/^appos(:|$)/ && $parent->ord() > $node->ord())
    {
        $deprel = 'dislocated';
        $node->set_deprel($deprel);
        # However, this could mean that we have created another case where
        # an 'obl' is attached to a 'dislocated' nominal. Let's check the
        # children.
        if($node->is_noun())
        {
            foreach my $c ($node->children())
            {
                if($c->deprel() =~ m/^obl(:|$)/)
                {
                    $c->set_deprel('nmod');
                }
            }
        }
    }
    $self->fix_auxiliary_verb($node);
}



#------------------------------------------------------------------------------
# Fix auxiliary verb that should not be auxiliary.
#------------------------------------------------------------------------------
sub fix_auxiliary_verb
{
    my $self = shift;
    my $node = shift;
    if($node->lemma() eq 'لسنا' && $node->tag() eq 'X' && $node->deprel() =~ m/^cop(:|$)/)
    {
        $node->set_tag('AUX');
        $node->iset()->add('pos' => 'verb', 'verbtype' => 'aux');
    }
    if($node->is_verb() && $node->deprel() =~ m/^cop(:|$)/
        # For now, do not touch the copulas in Arabic-PUD: kAn-u_1, >aSobaH_1, bAt-i_1, Ead~-u_1, jaEal-a_1, layosa_1, EAd-u_1, {iEotabar_1, Zal~-a_1, baqiy-a_1
        && $node->lemma() !~ m/^(kAn-u_1|>aSobaH_1|bAt-i_1|Ead~-u_1|jaEal-a_1|layosa_1|EAd-u_1|\{iEotabar_1|Zal~-a_1|baqiy-a_1)$/)
    {
        if($node->lemma() !~ m/^(كَان|لَيس|لسنا)$/)
           # $node->lemma() =~ m/^صَرَّح$/ # ṣarraḥ
        {
            my $pnom = $node->parent();
            my $parent = $pnom->parent();
            my $deprel = $pnom->deprel();
            # The nominal predicate may have been attached as a non-clause;
            # however, now we have definitely a clause.
            $deprel =~ s/^nsubj/csubj/;
            $deprel =~ s/^i?obj/ccomp/;
            $deprel =~ s/^(advmod|obl)/advcl/;
            $deprel =~ s/^(nmod|amod|appos|nummod)/acl/;
            # Be prepared for incorrect input: the pnom's deprel could have been
            # something weird which we don't want to inherit.
            $deprel =~ s/^(det|cop|aux|case|mark|cc)(:|$)/parataxis$2/;
            $node->set_parent($parent);
            $node->set_deprel($deprel);
            $pnom->set_parent($node);
            $pnom->set_deprel('xcomp');
            # Subject, adjuncts and other auxiliaries go up (also 'expl:pv' in "stát se").
            # Noun modifiers remain with the nominal predicate.
            my @children = $pnom->children();
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^([nc]subj|obj|obl|advmod|discourse|vocative|expl)(:|$)/)
                {
                    ###!!! Warning! This could lead to a double-subject (or double-object)
                    ###!!! situation if the parent already has a subject/object.
                    my @mychildren = $node->children();
                    log_info("My children = ".join(', ', @mychildren));
                    my @mysubjects = grep {$_->deprel() =~ m/^[nc]subj/} (@mychildren);
                    my @myobjects = grep {$_->deprel() =~ m/^obj/} (@mychildren);
                    if(scalar(@mychildren) > 0 &&
                       ($child->deprel() =~ m/^[nc]subj/ && scalar(@mysubjects) > 0 ||
                        $child->deprel() eq m/^obj/ && scalar(@myobjects) > 0))
                    {
                        ###!!! Ideally, we should find a better solution.
                        $child->set_deprel('dep');
                    }
                    $child->set_parent($node);
                }
            }
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^(aux|mark|cc)(:|$)/)
                {
                    unless($self->would_be_nonprojective($node, $child) || $self->would_cause_nonprojectivity($node, $child))
                    {
                        $child->set_parent($node);
                    }
                }
            }
            # Sometimes punctuation must be raised because of nonprojectivity.
            # Sometimes punctuation causes nonprojectivity when raised.
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^punct(:|$)/)
                {
                    unless($self->would_be_nonprojective($node, $child) || $self->would_cause_nonprojectivity($node, $child))
                    {
                        $child->set_parent($node);
                    }
                }
            }
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->iset()->clear('verbtype');
            $node->set_tag('VERB');
        }
    }
}



#------------------------------------------------------------------------------
# Certain node types are supposed to be leaves. If they have children, we
# will raise the children. However, we can only do it after we have fixed
# all deprels, thus it cannot be included in fix_constructions() above.
#------------------------------------------------------------------------------
sub fix_leaves
{
    my $self = shift;
    my $node = shift;
    # Some types of dependents, such as 'conj', are allowed even under function
    # words.
    if($node->deprel() !~ m/^(root|fixed|goeswith|conj|punct)(:|$)/)
    {
        while($node->parent()->deprel() =~ m/^(det|cop|aux|case|mark|cc|fixed|goeswith|punct)(:|$)/)
        {
            my $grandparent = $node->parent()->parent();
            $node->set_parent($grandparent);
        }
    }
}



#------------------------------------------------------------------------------
# Fix fixed multiword expressions.
#------------------------------------------------------------------------------
my @_fixed_expressions;
my @fixed_expressions;
BEGIN
{
    # This function processes multiword expressions that should be annotated
    # as fixed (regardless what their annotation in PADT was), as well as those
    # that may be considered fixed by some, but should not. For those that should
    # not be fixed we provide the prescribed tree structure; if the expression
    # should not be one constituent, all components will be attached to the same
    # parent outside the expression; alternatively, those that already are attached
    # outside can keep their attachment (this can be signaled by parent=-1 instead
    # of 0; deprel should still be provided just in case the node has its parent
    # inside and we have to change it).
    @_fixed_expressions =
    (
        # lc(forms), mode, UPOS tags, ExtPos, deps (parent:deprel)
        # modes:
        # - always ... apply as soon as the lowercased forms match
        # - catena ... apply only if the nodes already form a catena in the tree (i.e. avoid accidental grabbing random collocations)
        # - subtree .. apply only if the nodes already form a full subtree (all descendants included in the expression)
        # - fixed .... apply only if it is already annotated as fixed (i.e. just normalize morphology and add ExtPos)
        #---------------------------------------------------------
        # Multiword adjectives.
        ###!!! We hard-code certain disambiguations (the expression is rare, in PDT there is just one occurrence of "ty tam", and we know it is masculine inanimate and not feminine).
        ###!!! However, in PDTSC (test/pdtsc_085_1.06#10), we have: "Jak to tam u vás vlastně vypadá?"
        ['ta tam',             'always',  'ten tam',            'DET ADV',             'PDFS1---------- Db-------------',                 'pos=adj|prontype=dem|gender=fem|number=sing|case=nom|extpos=adj pos=adv|prontype=dem', '-1:dep 1:fixed'],
        ['ten tam',            'always',  'ten tam',            'DET ADV',             'PDYS1---------- Db-------------',                 'pos=adj|prontype=dem|gender=masc|number=sing|case=nom|extpos=adj pos=adv|prontype=dem', '-1:dep 1:fixed'],
        ['ti tam',             'always',  'ten tam',            'DET ADV',             'PDMP1---------- Db-------------',                 'pos=adj|prontype=dem|gender=masc|animacy=anim|number=plur|case=nom|extpos=adj pos=adv|prontype=dem', '-1:dep 1:fixed'],
        ['to tam',             'fixed',   'ten tam',            'DET ADV',             'PDNS1---------- Db-------------',                 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=adj pos=adv|prontype=dem', '-1:dep 1:fixed'],
        ['ty tam',             'always',  'ten tam',            'DET ADV',             'PDIP1---------- Db-------------',                 'pos=adj|prontype=dem|gender=masc|animacy=inan|number=plur|case=nom|extpos=adj pos=adv|prontype=dem', '-1:dep 1:fixed'],
        # Multiword adverbs.
        ['víc než',            'fixed',   'více než',           'ADV SCONJ',           'Dg-------2A---1 J,-------------',                 'pos=adv|polarity=pos|degree=cmp|extpos=adv pos=conj|conjtype=sub', '0:advmod 1:fixed'],
        ['více než',           'fixed',   'více než',           'ADV SCONJ',           'Dg-------2A---- J,-------------',                 'pos=adv|polarity=pos|degree=cmp|extpos=adv pos=conj|conjtype=sub', '0:advmod 1:fixed'],
        ['všeho všudy',        'always',  'všechen všudy',      'DET ADV',             'PLZS2---------- Db-------------',                 'pos=adj|prontype=tot|gender=neut|number=sing|case=gen|extpos=adv pos=adv|prontype=tot', '0:advmod 1:fixed'],
        # Expressions like "týden co týden": Since the "X co X" pattern is not productive,
        # we should treat it as a fixed expression with an adverbial meaning.
        ['večer co večer',     'always',  'večer co večer',     'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                     '0:advmod 1:fixed 1:fixed'],
        # Multiword prepositions.
        ['za účelem',          'fixed',   'za účel',            'ADP NOUN',            'RR--7---------- NNIS7-----A----',                 'pos=adp|adpostype=prep|case=ins|extpos=adp pos=noun|nountype=com|gender=masc|animacy=inan|number=sing|case=ins',                                       '0:case 1:fixed'],
        # Multiword subordinators.
        ['ما اذا',             'fixed',   'مَا إِذَا',             'DET SCONJ',           'S--------- C---------',                           'pos=adj|prontype=int|extpos=sconj pos=conj|conjtype=coor',                                '0:mark 1:fixed'], # mā ʾiḏā
        ['ما إذا',             'fixed',   'مَا إِذَا',             'DET SCONJ',           'S--------- C---------',                           'pos=adj|prontype=int|extpos=sconj pos=conj|conjtype=coor',                                '0:mark 1:fixed'], # mā ʾiḏā
        # Multiword coordinators.
        ['nebo - li',          'always',  'nebo - li',          'CCONJ PUNCT SCONJ',   'J^------------- Z:------------- J,-------------', 'pos=conj|conjtype=coor|extpos=cconj pos=punc pos=conj|conjtype=sub',                               '0:cc 3:punct 1:fixed'],
        # There is a dedicated function fix_to_jest() (called from fix_constructions() before coming here), which make sure that the right instances of "to je" and "to jest" are annotated as fixed expressions.
        ['to je',              'fixed',   'ten být',            'DET AUX',             'PDNS1---------- VB-S---3P-AAI--',                 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=cconj pos=verb|verbtype=aux|polarity=pos|number=sing|person=3|verbform=fin|mood=ind|tense=pres|voice=act|aspect=imp', '0:cc 1:fixed'],
        ['to jest',            'fixed',   'ten být',            'DET AUX',             'PDNS1---------- VB-S---3P-AAI-2',                 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=cconj pos=verb|verbtype=aux|polarity=pos|number=sing|person=3|verbform=fin|mood=ind|tense=pres|voice=act|aspect=imp', '0:cc 1:fixed'],
        ['to znamená , aniž',  'always',  'ten znamenat , aniž', 'DET VERB PUNCT SCONJ', 'PDNS1---------- VB-S---3P-AAI-- Z:------------- J,-------------', 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=cconj pos=verb|polarity=pos|number=sing|person=3|verbform=fin|mood=ind|tense=pres|voice=act|aspect=imp pos=punc pos=conj|conjtype=sub', '0:cc 1:fixed 0:punct 0:mark'],
        ['to znamená , až',    'always',  'ten znamenat , až',  'DET VERB PUNCT SCONJ', 'PDNS1---------- VB-S---3P-AAI-- Z:------------- J,-------------', 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=cconj pos=verb|polarity=pos|number=sing|person=3|verbform=fin|mood=ind|tense=pres|voice=act|aspect=imp pos=punc pos=conj|conjtype=sub', '0:cc 1:fixed 0:punct 0:mark'],
        ['to znamená',         'fixed',   'ten znamenat',       'DET VERB',            'PDNS1---------- VB-S---3P-AAI--',                 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=cconj pos=verb|polarity=pos|number=sing|person=3|verbform=fin|mood=ind|tense=pres|voice=act|aspect=imp',              '0:cc 1:fixed'],
        # The following expressions should not be annotated as fixed.
        ['a jestli',           'always',  'a jestli',           'CCONJ SCONJ',         'J^------------- J,-------------',                 'pos=conj|conjtype=coor pos=conj|conjtype=sub',  '-1:cc -1:mark'],
        ['a jestliže',         'always',  'a jestliže',         'CCONJ SCONJ',         'J^------------- J,-------------',                 'pos=conj|conjtype=coor pos=conj|conjtype=sub',  '-1:cc -1:mark'],
    );
    foreach my $e (@_fixed_expressions)
    {
        my $expression = $e->[0];
        my @forms = split(/\s+/, $e->[0]);
        my $mode = $e->[1];
        my @lemmas = defined($e->[2]) ? split(/\s+/, $e->[2]) : ();
        my @upos = defined($e->[3]) ? split(/\s+/, $e->[3]) : ();
        my @xpos = defined($e->[4]) ? split(/\s+/, $e->[4]) : ();
        my @feats = ();
        if(defined($e->[5]))
        {
            my @_feats = split(/\s+/, $e->[5]);
            foreach my $_f (@_feats)
            {
                my @fv = split(/\|/, $_f);
                my %fv;
                foreach my $fv (@fv)
                {
                    next if($fv eq '_');
                    my ($f, $v) = split(/=/, $fv);
                    $fv{$f} = $v;
                }
                push(@feats, \%fv);
            }
        }
        my @deps = split(/\s+/, $e->[6]);
        my @parents;
        my @deprels;
        foreach my $dep (@deps)
        {
            my ($p, $d);
            if($dep =~ m/^(-1|[0-9]+):(.+)$/)
            {
                $p = $1;
                $d = $2;
            }
            else
            {
                log_fatal("Dependency not in form PARENTID:DEPREL");
            }
            if($p < -1 || $p > scalar(@deps))
            {
                log_fatal("Parent index out of range")
            }
            push(@parents, $p);
            push(@deprels, $d);
        }
        push(@fixed_expressions, {'expression' => $expression, 'mode' => $mode, 'forms' => \@forms, 'lemmas' => \@lemmas, 'upos' => \@upos, 'xpos' => \@xpos, 'feats' => \@feats, 'parents' => \@parents, 'deprels' => \@deprels});
    }
}

#------------------------------------------------------------------------------
sub fixed_expression_starts_at_node
{
    my $self = shift;
    my $expression = shift;
    my $node = shift;
    my $current_node = $node;
    foreach my $w (@{$expression->{forms}})
    {
        if(!defined($current_node))
        {
            return 0;
        }
        my $current_form = lc($current_node->form());
        if($current_form ne $w)
        {
            return 0;
        }
        $current_node = $current_node->get_next_node();
    }
    return 1;
}

#------------------------------------------------------------------------------
sub check_fixed_expression_mode
{
    my $self = shift;
    my $found_expression = shift; # hash ref
    my $expression_nodes = shift; # array ref
    my $parent_nodes = shift; # array ref
    if($found_expression->{mode} =~ m/^(catena|subtree|fixed)$/)
    {
        # There must be exactly one member node whose parent is not member.
        my $n_components = 0;
        my $head;
        for(my $i = 0; $i <= $#{$expression_nodes}; $i++)
        {
            my $en = $expression_nodes->[$i];
            my $pn = $parent_nodes->[$i];
            if(!any {$_ == $pn} (@{$expression_nodes}))
            {
                $n_components++;
                $head = $en;
            }
            else
            {
                # In fixed mode, all inner relations must be 'fixed' or 'punct'.
                if($found_expression->{mode} eq 'fixed' && $en->deprel() !~ m/^(fixed|punct)(:|$)/)
                {
                    #my $deprel = $en->deprel();
                    #log_info("Expression '$found_expression->{expression}': Stepping back because of deprel '$deprel', i=$i");
                    return 0;
                }
            }
        }
        if($n_components != 1)
        {
            #my $pords = join(',', map {$_->ord()} (@{$parent_nodes}));
            #log_info("Expression '$found_expression->{expression}': Stepping back because of $n_components components; parent ords $pords");
            return 0;
        }
        if($found_expression->{mode} eq 'subtree' && scalar($head->get_descendants({'add_self' => 1})) > scalar(@{$expression_nodes}))
        {
            #log_info("Expression '$found_expression->{expression}': Stepping back because there are more descendants than the expression itself");
            return 0;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
sub is_in_list
{
    my $self = shift;
    my $node = shift;
    my @list = @_;
    return any {$_ == $node} (@list);
}
sub is_in_or_depends_on_list
{
    my $self = shift;
    my $node = shift;
    my @list = @_;
    return any {$_ == $node || $node->is_descendant_of($_)} (@list);
}

#------------------------------------------------------------------------------
sub fix_fixed_expressions
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    ###!!! Hack: The most frequent type is multiword prepositions. There are thousands of them.
    # For now, I am not listing all of them in the table above, but at least they should get ExtPos.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'fixed' && $node->parent()->deprel() eq 'case')
        {
            $node->parent()->iset()->set('extpos', 'adp');
        }
        elsif($node->deprel() eq 'fixed' && $node->parent()->deprel() eq 'mark')
        {
            $node->parent()->iset()->set('extpos', 'sconj');
        }
        elsif($node->deprel() eq 'fixed' && $node->parent()->deprel() eq 'cc')
        {
            $node->parent()->iset()->set('extpos', 'cconj');
        }
        elsif($node->deprel() eq 'fixed' && $node->parent()->deprel() eq 'advmod')
        {
            $node->parent()->iset()->set('extpos', 'adv');
        }
    }
    foreach my $node (@nodes)
    {
        # Is the current node first word of a known fixed expression?
        my $found_expression;
        foreach my $e (@fixed_expressions)
        {
            if($self->fixed_expression_starts_at_node($e, $node))
            {
                $found_expression = $e;
                last;
            }
        }
        next unless(defined($found_expression));
        # Now we know we have come across one of the known expressions.
        # Get the expression nodes and find a candidate for the external parent.
        my @expression_nodes;
        my @parent_nodes;
        my $current_node = $node;
        foreach my $w (@{$found_expression->{forms}})
        {
            push(@expression_nodes, $current_node);
            push(@parent_nodes, $current_node->parent());
            $current_node = $current_node->get_next_node();
        }
        # If we require for this expression that it already is a catena, check it now.
        if(!$self->check_fixed_expression_mode($found_expression, \@expression_nodes, \@parent_nodes))
        {
            next;
        }
        log_info("Found fixed expression '$found_expression->{expression}'");
        my $parent;
        foreach my $n (@parent_nodes)
        {
            # The first parent node that lies outside the expression will become
            # parent of the whole expression. (Just in case the nodes of the expression
            # did not form a constituent. Normally we expect there is only one parent
            # candidate.) Note that the future parent must not only lie outside the
            # expression, it also must not be dominated by any member of the expression!
            # Otherwise we would be creating a cycle.
            if(!$self->is_in_or_depends_on_list($n, @expression_nodes))
            {
                $parent = $n;
                last;
            }
        }
        log_fatal('Something is wrong. We should have found a parent.') if(!defined($parent));
        # Normalize morphological annotation of the nodes in the fixed expression.
        for(my $i = 0; $i <= $#expression_nodes; $i++)
        {
            $expression_nodes[$i]->set_lemma($found_expression->{lemmas}[$i]) if defined($found_expression->{lemmas}[$i]);
            $expression_nodes[$i]->set_tag($found_expression->{upos}[$i]) if defined($found_expression->{upos}[$i]);
            $expression_nodes[$i]->set_conll_pos($found_expression->{xpos}[$i]) if defined($found_expression->{xpos}[$i]);
            $expression_nodes[$i]->iset()->set_hash($found_expression->{feats}[$i]) if defined($found_expression->{feats}[$i]);
        }
        # If the expression should indeed be fixed, then the first node should be
        # attached to the parent and all other nodes should be attached to the first
        # node. However, if we are correcting a previously fixed annotation to something
        # non-fixed, there are more possibilities. Therefore we always require the
        # relative addresses of the parents (0 points to the one external parent we
        # identified in the previous section, -1 allows to keep the external parent).
        # First attach the nodes whose new parent lies outside the expression.
        # That way we prevent cycles that could arise when attaching other nodes
        # to these nodes.
        # Special care needed if the external parent is the artificial root.
        my $subroot_node;
        for(my $i = 0; $i <= $#expression_nodes; $i++)
        {
            my $parent_i = $found_expression->{parents}[$i];
            if($parent_i <= 0)
            {
                if($parent_i == -1 && !$self->is_in_or_depends_on_list($parent_nodes[$i], @expression_nodes))
                {
                    # Keep the current parent, which is already outside the
                    # examined expression.
                    if($expression_nodes[$i]->parent()->is_root())
                    {
                        $subroot_node = $expression_nodes[$i];
                    }
                }
                elsif($parent->is_root())
                {
                    if(defined($subroot_node))
                    {
                        $expression_nodes[$i]->set_b_e_dependency($subroot_node, $self->decide_obl_or_nmod($subroot_node, $found_expression->{deprels}[$i]));
                    }
                    else
                    {
                        $expression_nodes[$i]->set_b_e_dependency($parent, 'root');
                        $subroot_node = $expression_nodes[$i];
                    }
                }
                else
                {
                    $expression_nodes[$i]->set_b_e_dependency($parent, $self->decide_obl_or_nmod($parent, $found_expression->{deprels}[$i]));
                }
            }
            # To prevent temporary cycles when changing the internal structure
            # of the expression, first reattach all nodes to the parent, too.
            else
            {
                $expression_nodes[$i]->set_b_e_dependency($parent, 'dep:temporary');
            }
        }
        # Now modify the attachments inside the expression.
        for(my $i = 0; $i <= $#expression_nodes; $i++)
        {
            my $parent_i = $found_expression->{parents}[$i];
            if($parent_i > 0)
            {
                $expression_nodes[$i]->set_b_e_dependency($expression_nodes[$parent_i-1], $self->decide_obl_or_nmod($expression_nodes[$parent_i-1], $found_expression->{deprels}[$i]));
            }
        }
    }
    foreach my $node (@nodes)
    {
        # No need for recursion because there should not be chains of fixed relations.
        if($node->deprel() !~ m/^root(:|$)/ && $node->parent()->deprel() =~ m/^fixed(:|$)/)
        {
            $node->set_parent($node->parent()->parent());
        }
    }
}
###!!!
# If the deprel prescribed by the table is obl, look at the parent and see if
# it should not actually be nmod. We have been checking this in Udep::check_obl_under_nominal()
# and we do not want to spoil it here again.
sub decide_obl_or_nmod
{
    my $self = shift;
    my $new_parent = shift;
    my $suggested_deprel = shift;
    if($suggested_deprel =~ m/^obl(:|$)/ && $new_parent->deprel() =~ m/^(nsubj|obj|iobj|obl|vocative|dislocated|expl|nmod|nummod)(:|$)/)
    {
        return 'nmod';
    }
    return $suggested_deprel;
}



#------------------------------------------------------------------------------
###!!! This is a copy of a function from HamleDT::Udep. We need to check it
###!!! again after changes of the tree here. But the whole organization is
###!!! becoming quite messy. Maybe this should be a separate block.
# Checks whether a node is the head of a nominal that is not at the same time
# the head of a clause (nominal predicate). Looks at upos and deprel (its main
# / universal part). If it cannot be sure that the answer is 1, it will return
# 0 (for example, if the deprel is 'appos', the node is probably not clausal,
# but we cannot completely exclude it, therefore we will return 0).
#------------------------------------------------------------------------------
sub is_nominal_not_predicate
{
    my $self = shift;
    my $node = shift;
    if(($node->is_noun() || $node->is_pronominal() || $node->is_numeral()) && $node->deprel() =~ m/^(nsubj|obj|iobj|obl|vocative|dislocated|expl|nmod|nummod)(:|$)/)
    {
        return 1;
    }
    return 0;
}



#------------------------------------------------------------------------------
###!!! This is a copy of a function from HamleDT::Udep. We need to check it
###!!! again after changes of the tree here. But the whole organization is
###!!! becoming quite messy. Maybe this should be a separate block.
# If a nominal modifies another nominal and the parent is not a nominal
# predicate of a clause, their relation cannot be 'obl' and must be 'nmod'.
#------------------------------------------------------------------------------
sub check_obl_under_nominal
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^obl(:|$)/ && $self->is_nominal_not_predicate($node->parent()))
        {
            $node->set_deprel('nmod');
        }
    }
}



#------------------------------------------------------------------------------
# Makes sure that no fixed expressions have gaps in them. This is possible in
# UD, although it triggers a warning. But we believe that such expressions are
# not fixed enough, at least in Czech.
###!!! In the future, we should move this decision to an earlier phase, i.e.,
# during the harmonization of the Prague style, where we could introduce a new
# Fixed relation and a corresponding special type of nonterminal phrase.
# Perhaps we should ban also non-gappy versions of expressions that can have
# gaps, or all multiword prepositions whatsoever. (But we may want to preserve
# them in MISC and/or in the enhanced graph.)
#------------------------------------------------------------------------------
sub fix_fixed_expressions_with_gaps
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        my @fixed = grep {$_->deprel() =~ m/^fixed(:|$)/} ($node->children({'ordered' => 1}));
        if(scalar(@fixed) > 0)
        {
            unshift(@fixed, $node);
            # We have a fixed expression. Does it have a gap? The UD validator
            # would ignore a gap which only contains punctuation.
            my $minord = $fixed[0]->ord();
            my $maxord = $fixed[-1]->ord();
            my @gap = grep {$_->ord() > $minord && $_->ord() < $maxord && !in($_, @fixed)} (@nodes);
            if(scalar(@gap) > 0)
            {
                ###!!! There are various patterns that call for different solutions.
                ###!!! For example, "z jeho strany" (the possessive in the gap is the parent of the fixed expression "ze strany")
                ###!!! or "současně i s X" (the rhematizer "i" in the gap has the same parent as the fixed expression "současně s").
                ###!!! For the moment, we take an easy (but wrong) approach of
                ###!!! simply re-attaching all members directly to the parent.
                if(scalar(@fixed) == 2 && scalar(@gap) == 1 && $gap[0]->is_possessive())
                {
                    $fixed[1]->set_parent($gap[0]->parent());
                    $fixed[1]->set_deprel($gap[0]->deprel() == 'det' ? 'nmod' : $gap[0]->deprel());
                    $fixed[0]->set_parent($fixed[1]);
                    $gap[0]->set_parent($fixed[1]);
                    $gap[0]->set_deprel('det');
                }
                # Skip instances where the gap consists of a single punctuation symbol.
                elsif(!(scalar(@gap) == 1 && $gap[0]->deprel() =~ m/^punct(:|$)/))
                {
                    my $parent = $node->parent();
                    my $deprel = $node->deprel();
                    foreach my $f (@fixed[1..$#fixed])
                    {
                        $f->set_parent($parent);
                        $f->set_deprel($deprel);
                    }
                }
            }
        }
    }
}
sub in
{
    my $element = shift;
    my @list = @_;
    return any {$_ == $element} (@list);
}



#------------------------------------------------------------------------------
# Fixes various annotation errors in individual sentences. It is preferred to
# fix them when harmonizing the Prague style but in some cases the conversion
# would be still difficult, so we do it here.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $node = shift;
    my $spanstring = $self->get_node_spanstring($node);
    if($spanstring =~ m/^التي ، و التي تعتبر هذا الموسم/)
    {
        my @subtree = $self->get_node_subtree($node);
        if($subtree[0]->parent() == $subtree[3])
        {
            $subtree[0]->set_parent($node->parent());
        }
    }
    # الاستثمارات الأجنبية " ليس إلى مصر فقط و لكن إلى كل الدول النامية "
    # Zahraniční investice „nejen do Egypta, ale do všech rozvojových zemí“
    #elsif($spanstring =~ m/^الاستثمارات الأجنبية " ليس إلى مصر فقط و لٰكن إلى كل الدول النامية " ،$/)
    #elsif($spanstring =~ m/^الاستثمارات الأجنبية/)
    elsif($spanstring eq 'الاستثمارات الأجنبية " ليس إلى مصر فقط و لٰكن إلى كل الدول النامية "')
    {
        #log_warn('JSEM TU: '.$spanstring);
        my @subtree = $self->get_node_subtree($node);
        $subtree[5]->set_parent($subtree[0]);
        $subtree[5]->set_deprel('nmod');
        $subtree[4]->set_parent($subtree[5]);
        $subtree[4]->set_deprel('case');
        $subtree[3]->set_parent($subtree[5]);
        $subtree[3]->set_deprel('cop');
        $subtree[2]->set_parent($subtree[5]);
        $subtree[10]->set_parent($subtree[5]);
        $subtree[13]->set_parent($subtree[5]);
    }
}



#------------------------------------------------------------------------------
# For a candidate attachment, tells whether it would be nonprojective. We want
# to use the relatively complex method Node->is_nonprojective(), which means
# that we must temporarily attach the node to the candidate parent. This will
# throw an exception if there is a cycle. But then we should not be considering
# the parent anyways.
#------------------------------------------------------------------------------
sub would_be_nonprojective
{
    my $self = shift;
    my $parent = shift;
    my $child = shift;
    # Remember the current attachment of the child so we can later restore it.
    my $current_parent = $child->parent();
    # We could now check for potential cycles by calling $parent->is_descendant_of($child).
    # But it is not clear what we should do if the answer is yes. And at present,
    # this module does not try to attach punctuation nodes that are not leaves.
    $child->set_parent($parent);
    my $nprj = $child->is_nonprojective();
    # Restore the current parent.
    $child->set_parent($current_parent);
    return $nprj;
}



#------------------------------------------------------------------------------
# For a candidate attachment, tells whether it would cause a new
# nonprojectivity, provided the rest of the tree stays as it is. We want to
# use the relatively complex method Node->get_gap(), which means that we must
# temporarily attach the node to the candidate parent. This will throw an
# exception if there is a cycle. But then we should not be considering the
# parent anyways.
#------------------------------------------------------------------------------
sub would_cause_nonprojectivity
{
    my $self = shift;
    my $parent = shift;
    my $child = shift;
    # Remember the current attachment of the child so we can later restore it.
    my $current_parent = $child->parent();
    # We could now check for potential cycles by calling $parent->is_descendant_of($child).
    # But it is not clear what we should do if the answer is yes. And at present,
    # this module does not try to attach punctuation nodes that are not leaves.
    $child->set_parent($parent);
    # The punctuation node itself must not cause nonprojectivity of others.
    # If the gap contains other, non-punctuation nodes, we could hold those
    # other nodes responsible for the gap, but then the child would have to be
    # attached to them and not to something else. So we will consider any gap
    # a problem.
    my @gap = $child->get_gap();
    # Restore the current parent.
    $child->set_parent($current_parent);
    return scalar(@gap);
}



1;

=over

=item Treex::Block::HamleDT::AR::FixUD

Arabic-specific post-processing after the treebank has been converted from the
Prague style to Universal Dependencies. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

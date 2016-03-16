package Treex::Block::HamleDT::PT::HarmonizeCintilUSD;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToPrague;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'pt::cintil',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

has punctuation_spaces_marked =>
(
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'Does the input use "*/" and "\*" to mark spaces around punctuation?',
);



#------------------------------------------------------------------------------
# Reads the Portuguese tree, converts morphosyntactic tags to Interset,
# converts dependency relations, transforms tree to adhere to the HamleDT
# guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);

    # Adjust the tree structure.
    # Phrase-based implementation of tree transformations (7.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->raise_function_words($root);
    $self->fix_comparative_constructions($root);
    # Make sure that all nodes have known deprels.
    $self->check_deprels($root);

    # $zone->sentence should contain the (surface, detokenized) sentence string.
    $self->fill_sentence($root);

    # ".*/" -> "." etc.
    #$self->normalize_punctuation_and_spaces($root);

    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Save Interset features to the "tag" attribute,
        # so we can see them in TrEd (tooltip shows also the categories).
        $node->set_tag(join ' ', $node->get_iset_values());
        # "em_" -> "em" etc.
        $self->fix_form($node);
        # Lowercase lemmas etc.
        $self->fix_lemma($node);
        # Adverbs (including rhematizers) should not depend on prepositions.
        #$self->rehang_rhematizers($node);
    }
    return;
}

#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        # Attributes that we may have to query.
        my $plemma = $parent->lemma();
        # Convert the labels.
        # Adverbial clause that functions as a modifier (adjunct).
        # Example: a vw ainda não tomou qualquer decisão , porque estão a analisar/ADVCL as várias hipóteses
        if($deprel eq 'ADVCL')
        {
            $deprel = 'Adv';
        }
        # Adverb that functions as adverbial modifier.
        # Example: muito barato
        elsif($deprel eq 'ADVMOD')
        {
            # The negation ("not") is also labeled ADVMOD but we want the deprel Neg for it.
            # Example: Hoje o Manuel não comprou um livro.
            # Translation: Today Manuel did not buy a book.
            if(lc($node->form()) eq 'não')
            {
                $deprel = 'Neg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # Adjectival modifier of a noun.
        # Example: um computador barato
        elsif($deprel eq 'AMOD')
        {
            $deprel = 'Atr';
        }
        # Apposition. (The examples do not seem similar to what PDT calls apposition.)
        # Example: uma grande vitória para mim/APPOS [APPOS(vitória, mim)]
        elsif($deprel eq 'APPOS')
        {
            $deprel = 'Apposition';
        }
        # Auxiliary verb. The examples seem to be reversed. In the following, infinitive is attached as AUX to the auxiliary verb "vai":
        # Example: o governo vai hoje assinar/AUX um protocolo
        elsif($deprel eq 'AUX')
        {
            $deprel = 'AuxV'; ###!!! Jak by tohle vypadalo v PDT?
        }
        # Preposition attached to its nominal argument is labeled CASE.
        # Example: em_/CASE o armazém
        elsif($deprel eq 'CASE')
        {
            $deprel = 'AuxP';
        }
        # Coordinating conjunction. At least this is the meaning of CC in the original Stanford Dependencies.
        # CINTIL seems to hide the real conjunction but it does not hesitate to label CC the comma in a multi-conjunct coordination.
        # Example: a retirada militar de hebron , os colonatos judeus [CC(colonatos, ,), PARATAXIS(retirada, colonatos)]
        elsif($deprel eq 'CC')
        {
            $deprel = 'AuxY';
            $node->wild()->{coordinator} = 1;
        }
        # Clausal complement of a predicate.
        # Example: sei que a herança não é boa/CCOMP
        elsif($deprel eq 'CCOMP')
        {
            $deprel = 'Obj';
        }
        # Complement (adverbial?)
        # Example: vivem aqui/COMP
        elsif($deprel eq 'COMP')
        {
            $deprel = 'Adv';
        }
        # Non-first conjunct is attached to the first conjunct as CONJ.
        elsif($deprel eq 'CONJ')
        {
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }
        # Copula is attached to the nominal predicate.
        # Example: este computador é/COP barato
        elsif($deprel eq 'COP')
        {
            $deprel = 'Cop';
        }
        # Clausal subject.
        # Example: quem não ficou satisfeito com o bombardeamento sobre srebrenica foi lord david owen [CSUBJ(lord, satisfeito)] ###!!!???
        elsif($deprel eq 'CSUBJ')
        {
            $deprel = 'Sb';
        }
        # Clausal subject of a passive verb.
        ###!!! There are 9 occurrences of CSUBJPASS in the data and they are probably errors. It is assigned to "que" instead of verbs.
        elsif($deprel eq 'CSUBJPASS')
        {
            $deprel = 'Sb';
        }
        # Uncategorized dependency.
        # Example: cerca de dois/DEP [DEP(cerca, dois)]
        elsif($deprel eq 'DEP')
        {
            $deprel = 'ExD'; ###!!!???
        }
        # Determiner attached to a noun.
        # Example: o cliente
        elsif($deprel eq 'DET')
        {
            $deprel = 'Atr';
            ###!!! HamleDT 2.0 does not set the AuxA deprel. We should do this in a separate block, so that this block produces HamleDT-compliant output.
            ###!!! However, we only use this block in Portuguese analysis for QTLeap, so we can bias it towards that goal.
            ###!!! (The blocks that construct t-trees from a-trees need AuxA to distinguish articles from other determiners.
            ###!!! They hide all a-nodes with Aux* deprels and articles shall be hidden while other determiners shall not.)
            $deprel = 'AuxA' if($node->iset()->is_article());
        }
        # Direct object of verb. (If there is one object, it is direct. If there are more, one of them is direct and the rest are indirect.)
        # Example: o cliente encomendou um computador/DOBJ barato
        elsif($deprel eq 'DOBJ')
        {
            $deprel = 'Obj';
        }
        # Indirect object of verb. (If there is one object, it is direct. If there are more, one of them is direct and the rest are indirect.)
        # Example: a criança obedece apenas a_ a mãe/IOBJ
        elsif($deprel eq 'IOBJ')
        {
            $deprel = 'Obj';
        }
        # MARK is typically used for subordinating conjunctions attached to the predicate of the subordinate clause.
        # Example: , porque/MARK o empreiteiro de_ a obra o demoveu [MARK(demoveu, porque)]
        elsif($deprel eq 'MARK')
        {
            $deprel = 'AuxC';
        }
        # Modifier (adjunct of a verb, not realized as an adverb).
        # Example: o manuel foi a_ a loja com a maria/MOD
        elsif($deprel eq 'MOD')
        {
            $deprel = 'Adv';
        }
        # Multi-word expression.
        # Example: vinte/NUMMOD e/MWE dois/MWE computadores
        elsif($deprel eq 'MWE')
        {
            # A head-first phrase with all dependents labeled Atr is the behavior closest to PDT.
            #$deprel = 'MWE'; ###!!! Atr?
            $deprel = 'Atr';
        }
        # NCMOD ###!!!??? It looks like failed conversion of prepositional phrases.
        # Example: chegam discretamente junto/PREPC a_ a cruz alta [PREPC(chegam, junto); NCMOD(junto, cruz)]
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NCMOD')
        {
            $deprel = 'Adv';
        }
        # Negation?
        # Example: que nem/NEG sequer devia ter começado [NEG(devia, nem)]
        # Translation lit.: that not even should have started
        # Translation: that should not even have started
        elsif($deprel eq 'NEG')
        {
            $deprel = 'Neg';
        }
        # Noun phrase that functions as an adverbial modifier.
        # Example: o elemento feminino está favorecido esta semana/NPADVMOD
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NPADVMOD')
        {
            $deprel = 'Adv';
        }
        # Noun phrase that functions as subject.
        # Example: este computador/NSUBJ é baratíssimo
        elsif($deprel eq 'NSUBJ')
        {
            $deprel = 'Sb';
        }
        # Nominal subject of a passive clause.
        # Example: sabemos que os prémios/NSUBJPASS são devidos
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NSUBJPASS')
        {
            $deprel = 'Sb';
        }
        # Numerical modifier (cardinal number modifying a counted noun).
        # The NUMMOD label is used for numbers expressed as words.
        # Numbers expressed using digits are labeled NUMBER.
        # Example: sete/NUMMOD outros suspeitos
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NUMMOD')
        {
            $deprel = 'Atr';
        }
        # Number expressed using digits. It may have the same function as NUMMOD.
        # Example: tinha 39/NUMBER anos
        # Example: desceu de 7,4780 para 7,4411 por cento
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NUMBER')
        {
            $deprel = 'Atr';
        }
        # Parataxis. Loosely attached clause.
        # Example: analisamos , dialogamos/PARATAXIS
        elsif($deprel eq 'PARATAXIS')
        {
            $deprel = 'ExD';
        }
        # Prepositional object of verb.
        # Example: o cliente estava contentíssimo com a compra/POBJ
        elsif($deprel eq 'POBJ')
        {
            $deprel = 'Obj';
        }
        # Possessive modifier.
        # Example: de_ os seus/POSS países balcânicos
        elsif($deprel eq 'POSS')
        {
            $deprel = 'Atr';
        }
        # Modifier of a possessive modifier.
        # Example: os seus próprios programas [POSSESSIVE(seus, próprios)]
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'POSSESSIVE')
        {
            $deprel = 'Atr';
        }
        # Some coordinating conjunctions are attached as PRECONJ and I do not know why.
        # Example: nem o restaurante... [PRECONJ(restaurante, nem)]
        elsif($deprel eq 'PRECONJ')
        {
            $deprel = 'AuxY';
        }
        # Predeterminer.
        # Example: quase/DET tudo/PREDET [PREDET(quase, tudo)]
        elsif($deprel eq 'PREDET')
        {
            $deprel = 'Atr';
        }
        # PREPC ###!!!??? It looks like failed conversion of prepositional phrases.
        # Example: chegam discretamente junto/PREPC a_ a cruz alta [PREPC(chegam, junto); NCMOD(junto, cruz)]
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'PREPC')
        {
            $deprel = 'AuxP';
        }
        # Punctuation.
        elsif($deprel eq 'PUNCT')
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }
        # Modifier of quantity??? ###!!!
        # Example: entre sete e oito hectares [QUANTMOD(sete, entre)]
        # Example: todos uns quatro computadores [QUANTMOD(quatro, uns)] ... ERROR?
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'QUANTMOD')
        {
            $deprel = 'AuxP';
        }
        # Root token, child of the artificial root node. Typically the main predicate.
        elsif($deprel eq 'ROOT')
        {
            $deprel = 'Pred'; ###!!! nebo ExD
        }
        # Clausal complement that does not have its independent subject.
        # It is controlled by a higher clause and its subject is either subject or object of the higher clause.
        # Example: nenhum membro quis falar/XCOMP
        elsif($deprel eq 'XCOMP')
        {
            $deprel = 'Obj';
        }
        $node->set_deprel($deprel);
    }
}


#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my @children = $node->children();
        # The AUX dependency relation should only be used with auxiliary verbs
        # (ter, haver). For some reason, the input data also use it with
        # arguments of phasal verbs, e.g. in "A encomenda acabou por chegar.",
        # there is AUX(acabou, chegar).
        if($node->deprel() eq 'AuxV' && $node->lemma() !~ m/^(ter|haver)$/i) #|ser|poder|dever|ir|vir|estar|ficar|continuar)$/i)
        {
            log_warn($node->get_address());
            $self->log_sentence($root);
            log_warn("A node is attached as AUX but its lemma is ".$node->lemma());
            $node->set_deprel('Obj');
        }
    }
}



#------------------------------------------------------------------------------
# Finds function words that are attached as leaves and should become heads:
#   - prepositions (AuxP)
#   - copula verbs (Cop)
# Reattaches the nodes as heads of the phrase. If there are both a preposition
# and a copula in one phrase (e.g. "A encomenda está em_o armazém."), the
# function proceeds left-to-right, i.e. the copula will govern the preposition.
#------------------------------------------------------------------------------
sub raise_function_words
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Cop' && $node->is_leaf() && !$node->is_member())
        {
            my $parent = $node->parent();
            if(defined($parent))
            {
                my $grandparent = $parent->parent();
                if(defined($grandparent))
                {
                    $node->set_parent($grandparent);
                    $node->set_deprel($parent->deprel());
                    $node->set_is_member($parent->is_member());
                    $parent->set_parent($node);
                    $parent->set_deprel('Pnom');
                    $parent->set_is_member(0);
                    # Find subject, if any (it is not forbidden to find even more (non-coordinate), although it would be strange).
                    my @subjects = grep {$_->get_real_afun() eq 'Sb'} $parent->children();
                    foreach my $subject (@subjects)
                    {
                        $subject->set_parent($node);
                    }
                    # Adverbial modifiers that appear before the copula should be attached to the copula.
                    if($node->ord() < $parent->ord())
                    {
                        my @premodifiers = grep {$_->ord() < $node->ord()} $parent->children();
                        foreach my $premod (@premodifiers)
                        {
                            $premod->set_parent($node);
                        }
                    }
                }
            }
        }
        elsif($node->deprel() eq 'AuxP' && $node->is_leaf() && !$node->is_member())
        {
            my $parent = $node->parent();
            if(defined($parent))
            {
                my $grandparent = $parent->parent();
                if(defined($grandparent))
                {
                    if(defined($grandparent->deprel()) && $grandparent->deprel() eq 'AuxP')
                    {
                        log_warn('Attaching a preposition under another preposition');
                    }
                    $node->set_parent($grandparent);
                    $parent->set_parent($node);
                    $node->set_is_member($parent->is_member());
                    $parent->set_is_member(0);
                }
            }
        }
    }
    return:
}

#------------------------------------------------------------------------------
# "maior de(deprel=AuxY,parent=que) o(deprel=AuxY,parent=que) que(deprel=DEP,deprel=ExD,parent=Maria) Maria(deprel=Dep,deprel=ExD,parent=maior)"
# ->
# "maior de(deprel=AuxC,parent=que) o(deprel=AuxC,parent=que) que(deprel=DEP,deprel=AuxC,parent=maior) Maria(deprel=Dep,deprel=Obj,parent=que)"
#------------------------------------------------------------------------------
sub fix_comparative_constructions
{
    my ($self, $root) = @_;
    foreach my $node ($root->get_descendants({ordered => 1}))
    {
        my $parent = $node->get_parent();
        if ($node->conll_deprel eq 'DEP' && $node->is_conjunction && $parent->conll_deprel eq 'DEP')
        {
            my @conjunction_nodes = $node->get_descendants({add_self=>1});
            next if any {!$_->is_conjunction} @conjunction_nodes;
            foreach my $conj_node (@conjunction_nodes)
            {
                $conj_node->set_deprel('AuxC');
            }
            $parent->set_deprel('Obj');
            $node->set_parent($parent->get_parent());
            $parent->set_parent($node);
        }
    }
    return;
}



#------------------------------------------------------------------------------
# Fixes various problems with input word forms.
#------------------------------------------------------------------------------
sub fix_form
{
    my ($self, $node) = @_;
    my $form = $node->form;

    # "em_" -> "em" etc. because the underscore character is reserved for formemes
    $form =~ s/_$//;

    # For some strange reason feminine definite singular articles are capitalized in CINTIL.
    $form = 'a' if $form eq 'A' && $node->ord > 1;

    $node->set_form($form);
    return;
}



#------------------------------------------------------------------------------
# Fixes various problems with input lemmas.
#------------------------------------------------------------------------------
sub fix_lemma
{
    my ($self, $node) = @_;
    my $lemma = $node->lemma;

    # Some words don't have assigned lemmas in CINTIL.
    $lemma = $node->form if $lemma eq '_';

    # Automatically analyzed lemmas sometimes include alternatives
    # (e.g. AFASTAR,AFASTADO). Let's hope the first is the most probable one and delete the rest.
    $lemma =~ s/(.),.+/$1/;

    ###!!! DZ: Why? A lemma is just an identifier, isn't it?
    # Otherwise, lemmas in CINTIL are all-uppercase.
    # Let's lowercase it except for proper names.
    $lemma = lc $lemma if $node->iset->nountype ne 'prop';

    # CINTIL-USD is buggy and lowercases first character of proper names
    $lemma = ucfirst $lemma if $node->iset->nountype eq 'prop';

    $node->set_lemma($lemma);
    return;
}



# Regex for detecting punctuation symbols
my $PUNCT= q{[\[\](),.;:'?-]};

#------------------------------------------------------------------------------
# The surface sentence cannot be stored in the CoNLL format, so let's try to
# reconstruct it. This is not needed for the analysis (in the real-world
# scenario, surface sentences will be on the input), but it helps when
# debugging, so the real sentence is shown in TrEd.
#------------------------------------------------------------------------------
sub fill_sentence
{
    my ($self, $root) = @_;
    my $str = join '', map {$_->form . ($_->no_space_after ? '' : ' ')} $root->get_descendants({ordered=>1});
    # Add spaces around the sentence, so we don't need to check for (\s|^) or \b.
    $str = " $str ";
    # For some strange reason feminine definite singular articles are capitalized in CINTIL.
    $str =~ s/ A / a /g;
    # Preposition + pronoun/article contractions, e.g. "de_" + "o" = "do"
    $str =~ s/por_ elos/pelos/g;
    $str =~ s/por_ elas/pelas/g;
    $str =~ s/por_ /pel/g; # pelo, pela
    $str =~ s/em_ /n/g;    # no, na, nos, nas, num, numa, nuns, numas
    $str =~ s/a_ a/à/g;    # à, às
    $str =~ s/a_ o/ao/g;   # ao, aos,
    $str =~ s/de_ /d/g;    # do, da, dos, das, dum, duma, duns, dumas, deste, desta,...
    $str =~ s/com_ mi/comigo/g;
    $str =~ s/com_ ti/contigo/g;
    $str =~ s/com_ si/consigo/g;

    # TODO: detached clitic, e.g. "dá" + "-se-" + "-lhe" + "o" = "dá-se-lho"
    $str =~ s/ -(se|lho|las|lo|ia)/-$1/g;
    # Preposition "de" was separated from the verb "haver" (keeping the hyphen).
    $str =~ s/ -de/-de/g;

    # Punctuation detokenization
    # CINTIL guidelines define special marking for spaces around punctuation "*/" and "\*",
    # but these are not used in CINTIL-DepBank (in conll format).
    if ($self->punctuation_spaces_marked)
    {
        $str =~ s{ \s       # single space
                   (\\\*)?  # $1 = optional "\*" means "space before"
                   ($PUNCT)  # $2 = punctuation
                   (\*/)?   # $3 = optiona; "*/" meand "space after"
                   \s       # single space
                }
                {($1 ? ' ' : '') . $2 . ($3 ? ' ' : '')}gxe;
    }
    else
    {
        $str =~ s/ ($PUNCT)/$1/g;
    }
    # Remove the spaces around the sentence
    $str =~ s/(^\s+|\s+$)//g;
    # Make sure the first word is capitalized
    $root->get_zone->set_sentence(ucfirst $str);
    return;
}



#------------------------------------------------------------------------------
# Some adverbs (mostly rhematizers "apenas", "mesmo", ...) depend on
# a preposition ("de", "a") in CINTIL. However, prepositions should have only
# one child in the HamleDT/Prague style (except for multi-word prepositions).
# E.g. "A encomenda está mesmo(deprel=Adv,parent=em_,newparent=armazém) em_ o armazém . "
#      "A criança obedece apenas(deprel=Adv,parent=a_,newparent=mãe) a_ a mãe ."
# Should we differentiate the scope of the rhematizer:
# "The child obeys only the mother" and "The child only obeys the mother"?
#------------------------------------------------------------------------------
sub rehang_rhematizers
{
    my ($self, $node) = @_;
    my $parent = $node->get_parent();
    if ($node->is_adverb && $parent->is_preposition)
    {
        my $sibling = $parent->get_children({following_only=>1, first_only=>1});
        if ($sibling && $sibling->is_noun)
        {
            $node->set_parent($sibling);
        }
    }
    return;
}



1;

=head1 NAME

Treex::Block::HamleDT::PT::HarmonizeCintilUSD

=head1 DESCRIPTION

Converts the CINTIL Portuguese treebank
(version October 2014, sent by João Rodrigues, Universal Stanford Dependencies)
to the annotation style of HamleDT/Prague.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

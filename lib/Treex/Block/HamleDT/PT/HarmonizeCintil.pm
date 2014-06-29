package Treex::Block::HamleDT::PT::HarmonizeCintil;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has '+iset_driver' => (default=>'pt::cintil');

my %CINTIL_DEPREL_TO_AFUN = (
    ROOT  => 'Pred',
    SJ    => 'Sb',   # Subject
    SJac  => 'Sb',   # Subject of an anticausative
    SJcp  => 'Sb',   # Subject of complex predicate
    DO    => 'Obj',  # Direct Object
    IO    => 'AuxP', # Indirect Object
    OBL   => 'AuxP', # Oblique Object
    M     => 'Atr',  # Modifier
    PRD   => 'Pnom', # Predicate
    SP    => 'Atr',  # Specifier
    N     => 'Atr',  # Name in multi‐word proper names
    CARD  => 'Atr',  # Cardinal in multi‐word cardinals
    PUNCT => 'AuxX', # Punctuation
    DEP   => 'AuxX', # Generic dependency (mostly commas)
);

sub process_zone {
    my ($self, $zone) = @_;

    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);

    my $root  = $zone->get_atree();
    my @nodes = $root->get_descendants();

    # $zone->sentence should contain the (surface, detokenized) sentence string.
    $self->fill_sentence($root);

    # Harmonize tags, forms, lemmas and dependency labels.
    foreach my $node (@nodes) {

        # Convert CoNLL POS tags and features to Interset and PDT if possible.
        $self->convert_tag($node);

        # Save Interset features to the "tag" attribute,
        # so we can see them in TrEd (tooltip shows also the categories).
        $node->set_tag(join ' ', $node->get_iset_values());

        # CINTIL (parsed output) uses ".*/" instead of ".", let's fix it.
        $self->fix_form($node);

        $self->fix_lemma($node);

        # Conversion from dependency relation tags to afuns (analytical function tags)
        my $afun = $self->guess_afun($node);
        $node->set_afun($afun || 'NR');
    }

    # See HamleDT::Harmonize for implementation details.
    $self->attach_final_punctuation_to_root($root);

    # See HamleDT::Harmonize and detect_coordination() for implementation details.
    $self->restructure_coordination($root);

    # Adverbs (including rhematizers) should not depend on prepositions.
    foreach my $node (@nodes) {
        $self->rehang_rhematizers($node);
    }
    
    return;
}

# According to the guidelines, the original CINTIL uses tags in form PoS#features,
# e.g. "CN#mp" (common noun, masculine plural). The Interset driver expects this format.
sub get_input_tag_for_interset {
    my ($self, $node) = @_;
    return $node->conll_pos() . '#' . $node->conll_feat;
}

sub fix_form {
    my ($self, $node) = @_;
    my $form = $node->form;

    # For punctuation and symbols, the default is no space before and no space after.
    # "*/" means a space after the token, "\*" means a space before.
    # Let's delete those marks and set the attribute no_space_after
    if ($form =~ /^(\\\*)?([,.'])(\*\/)?$/){
        $form = $2;
        my $space_before = $1 ? 1 : 0;
        my $space_after = $3 ? 1 : 0;
        $node->set_no_space_after(1) if !$space_after;
        if (!$space_before){
            my $prev_node = $node->get_prev_node();
            $prev_node->set_no_space_after(1) if $prev_node;
        }
    }

    # "em_" -> "em" etc. because the underscore character is reserved for formemes
    $form =~ s/_$//;

    # For some strange reason feminine definite singular articles are capitalized in CINTIL.
    $form = 'a' if $form eq 'A' && $node->ord > 1;
    
    $node->set_form($form);
    return;
}

sub fix_lemma {
    my ($self, $node) = @_;
    my $lemma = $node->lemma;

    # Some words don't have assigned lemmas in CINTIL.
    $lemma = $node->form if $lemma eq '_';

    # Automatically analyzed lemmas sometimes include alternatives
    # (e.g. AFASTAR,AFASTADO). Let's hope the first is the most probable one and delete the rest.
    $lemma =~ s/(.),.+/$1/;

    # Otherwise, lemmas in CINTIL are all-uppercase.
    # Let's lowercase it except for proper names.
    $lemma = lc $lemma if $node->iset->nountype ne 'prop';
    $node->set_lemma($lemma);
    return;
}


sub guess_afun {
    my ($self, $node) = @_;
    my $deprel   = $node->conll_deprel();
    my $pos      = $node->iset->pos;

    if ($deprel eq 'CONJ' && $node->get_parent->conll_deprel eq 'COORD'){
        $node->wild->{coordinator} = 1;
        return 'AuxY';
    }

    if ($deprel eq 'COORD'){
        $node->wild->{conjunct} = 1;
        return 'CoordArg';
    }
   
    if ($deprel eq 'C') {
        return 'Adv' if $pos eq 'noun';
        return 'Obj' if $pos eq 'verb';
    }

    # Coordinating conjunctions (deprel=CONJ, child_deprel=COORD) are already solved,
    # so pos=conj means subordinating conjunction.
    return 'AuxC' if $pos eq 'conj';
    return 'AuxP' if $pos eq 'adp';
    return 'Adv' if $pos eq 'adv';
    return 'AuxX' if $node->lemma eq ',';
    return 'AuxG' if $pos eq 'punc';
    return 'AuxA' if $node->iset->adjtype eq 'art'; # articles

    return $CINTIL_DEPREL_TO_AFUN{$node->conll_deprel};
}

sub detect_coordination {
    my ($self, $node, $coordination, $debug) = @_;
    $coordination->detect_moscow($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return non-head conjuncts, private modifiers of the head conjunct and all shared modifiers for the Stanford family of styles.
    # (Do not return delimiters, i.e. do not return all original children of the node. One of the delimiters will become the new head and then recursion would fall into an endless loop.)
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = grep {$_ != $node} ($coordination->get_conjuncts());
    push(@recurse, $coordination->get_shared_modifiers());
    push(@recurse, $coordination->get_private_modifiers($node));
    return @recurse;
}

# The surface sentence cannot be stored in the CoNLL format,
# so let's try to reconstruct it.
# This is not needed for the analysis (in real scenario, surface sentences will be on the input),
# but it helps when debugging, so the real sentence is shown in TrEd.
sub fill_sentence {
    my ($self, $root) = @_;
    my $str = join ' ', map {$_->form} $root->get_descendants({ordered=>1});

    # Add spaces around the sentence, so we don't need to check for (\s|^) or \b.
    $str = " $str ";

    # For some strange reason feminine definite singular articles are capitalized in CINTIL.
    $str =~ s/ A / a /g;

    # Contractions, e.g. "de_" + "o" = "do"
    $str =~ s/por_ elos/pelos/g;
    $str =~ s/por_ elas/pelas/g;
    $str =~ s/por_ /pel/g; # pelo, pela
    $str =~ s/em_ /n/g;    # no, na, nos, nas, num, numa, nuns, numas
    $str =~ s/a_ a/à/g;    # à, às
    $str =~ s/a_ o/ao/g;   # ao, aos,
    $str =~ s/de_ /d/g;    # do, da, dos, das, dum, duma, duns, dumas, deste, desta,...

    # TODO: detached clitic, e.g. "dá" + "-se-" + "-lhe" + "o" = "dá-se-lho"

    # Punctuation detokenization
    $str =~ s{ \s       # single space
               (\\\*)?  # $1 = optional "\*" means "space before"
               ([,.:])  # $2 = punctuation
               (\*/)?   # $3 = optiona; "*/" meand "space after"
               \s       # single space
             }
             {($1 ? ' ' : '') . $2 . ($3 ? ' ' : '')}gxe;

    # Remove the spaces around the sentence
    $str =~ s/(^ | $)//g;

    # Make sure the first word is capitalized
    $root->get_zone->set_sentence(ucfirst $str);
    return;
}

# Some adverbs (mostly rhematizers "apenas", "mesmo",...) depend on a preposition ("de", "a") in CINTIL.
# However, prepositions should have only one child in the HamleDT/Prague style (except for multi-word prepositions).
# E.g. "A encomenda está mesmo(afun=Adv,parent=em_,newparent=armazém) em_ o armazém . "
#      "A criança obedece apenas(afun=Adv,parent=a_,newparent=mãe) a_ a mãe ."
# Should we differentiate the scope of the rhematizer: "The child obeys only the mother" and "The child only obeys the mother"?
sub rehang_rhematizers {
    my ($self, $node) = @_;
    my $parent = $node->get_parent();
    if ($node->is_adverb && $parent->is_preposition){
        my $sibling = $parent->get_children({following_only=>1, first_only=>1});
        if ($sibling && $sibling->is_noun) {
            $node->set_parent($sibling);
        }
    }
    return;
}

1;

=head1 NAME 

Treex::Block::HamleDT::PT::HarmonizeCintil

=head1 DESCRIPTION

Convert Portuguese treebank CINTIL to HamleDT style.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


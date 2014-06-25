package Treex::Block::HamleDT::PT::HarmonizeCintil;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has '+iset_driver' => (default=>'pt::cintil');

my %CHANGE_FORM = (
    '.*/' => '.',
    ',*/' => ',',
    q{\*'} => q{'},
);

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

    foreach my $node (@nodes) {

        # Convert CoNLL POS tags and features to Interset and PDT if possible.
        $self->convert_tag($node);

        # Save interset features to the "tag" attribute,
        # so we can see them in TrEd
        #$node->set_tag($node->get_iset_conll_feat());
        $node->set_tag(join ' ', $node->get_iset_values());

        # CINTIL (parsed output) uses ".*/" instead of ".", let's fix it.
        $self->fix_form($node);

        $self->fix_lemma($node);

        # Conversion from dependency relation tags to afuns (analytical function tags)
        my $afun = $self->guess_afun($node);
        $node->set_afun($afun || 'NR');
    }

    $self->fill_sentence($zone);

    $self->attach_final_punctuation_to_root($root);

    $self->restructure_coordination($root);

    foreach my $node (@nodes) {
        $self->rehang_adverbs_to_verbs($node);
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
    my $real_form = $CHANGE_FORM{$node->form};
    if (defined $real_form) {
        $node->set_form($real_form);
    }
    return;
}

# Lowercase lemmas (CINTIL has all-uppercase) and fill form instead of "_".
sub fix_lemma {
    my ($self, $node) = @_;
    my $lemma = $node->lemma;
    $lemma = $node->form if $lemma eq '_';
    $node->set_lemma(lc $lemma);
    return;
}

sub guess_afun {
    my ($self, $node) = @_;
    my $deprel   = $node->conll_deprel();
    my $pos      = $node->iset->pos;

    if ($deprel eq 'CONJ' && any {$_->conll_deprel eq 'COORD'} $node->get_children()){
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
    my ($self, $zone) = @_;
    my $str = join ' ', map {$_->form} $zone->get_atree->get_descendants({ordered=>1});

    # Contractions, e.g. "de_" + "o" = "do"
    $str =~ s/por_ elos/pelos/g;
    $str =~ s/por_ elas/pelas/g;
    $str =~ s/por_ /pel/g; # pelo, pela
    $str =~ s/em_ /n/g;    # no, na, nos, nas, num, numa, nuns, numas
    $str =~ s/a_ a/à/g;    # à, às
    $str =~ s/a_ o/ao/g;   # ao, aos,
    $str =~ s/de_ /d/g;    # do, da, dos, das, dum, duma, duns, dumas, deste, desta,...

    # TODO: detached  clitic, e.g. "dá" + "-se-" + "-lhe" + "o" = "dá-se-lho"

    # Simple detokenization
    $str =~ s/ ([,.:])/$1/g;

    # Make sure the first word is capitalized
    $zone->set_sentence(ucfirst $str);
    return;
}

# Some adverbs (mostly rhematizers "apenas", "mesmo",...) depend on a preposition ("de", "a") in CINTIL.
# However, prepositions should have only one child in the HamleDT/Prague style (except for multi-word prepositions).
# E.g. "A encomenda está mesmo(afun=Adv,parent=em_,newparent=está) em_ o armazém . "
# TODO: In some cases, it may be more appropriate to rehang the adverb to its sibling, e.g.:
# "A criança obedece apenas(afun=Adv,parent=a_) a_ a mãe ."
# This may differentiate the scope of the rhematizer: "The child obeys only the mother" and "The child only obeys the mother"
sub rehang_adverbs_to_verbs {
    my ($self, $node) = @_;
    my $parent = $node->get_parent();
    if ($node->is_adverb && $parent->is_preposition){
        my $grandpa = $parent->get_parent();
        if ($grandpa->is_verb) {
            $node->set_parent($grandpa);
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


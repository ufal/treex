package Treex::Tool::Coreference::NodeFilter::DemonPron;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use Treex::Tool::Coreference::NodeFilter::Noun;

sub is_demon {
    my ($node) = @_;
    if ($node->language eq 'cs') {
        return _is_demon_cs($node);
    }
    if ($node->language eq 'en') {
        return _is_demon_en($node);
    }
    # Russian, German
    return _is_demon_prague($node);
}

sub _is_demon_cs {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return _is_demon_cs_a($node, $args);
    }
    else {
        return _is_demon_cs_t($node, $args);
    }
}

sub _is_demon_en {
    my ($node, $args) = @_;

    if ($node->get_layer eq "t") {
        return _is_demon_en_t($node, $args);
    }
    else {
        #return _is_demon_en_a($node, $args);
    }
}

sub _is_demon_cs_t {
    my ($tnode) = @_;
    return ($tnode->t_lemma eq "ten");
}

sub _is_demon_cs_a {
    my ($anode) = @_;
    return ($anode->lemma eq "ten");
}

sub _is_demon_en_t {
    my ($tnode) = @_;
    my $alex = $tnode->get_lex_anode;
    return 0 if (!$alex);
    my $is_det = ($alex->tag eq "DT");
    my $is_this = ($alex->lemma =~ /^(this|that|these|those)$/);
    my $is_sem_noun = Treex::Tool::Coreference::NodeFilter::Noun::is_sem_noun($tnode);
    return ($is_det && $is_this && $is_sem_noun);
}

sub _is_demon_prague {
    my ($node) = @_;
    if ($node->get_layer eq 'a') {
        _is_demon_prague_a($node);
    }
    else {
        _is_demon_prague_t($node);
    }
}

sub _is_demon_prague_a {
    my ($anode) = @_;
    return $anode->tag =~ /^PD/;
}

sub _is_demon_prague_t {
    my ($tnode) = @_;
    my $anode = $tnode->get_lex_anode;
    return 0 if (!defined $anode);
    return _is_demon_prague_a($anode);
}

1;

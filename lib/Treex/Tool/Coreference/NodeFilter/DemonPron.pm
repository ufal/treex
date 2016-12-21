package Treex::Tool::Coreference::NodeFilter::DemonPron;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

sub is_demon {
    my ($node) = @_;
    if ($node->language eq 'cs') {
        return _is_demon_cs($node);
    }
    #if ($tnode->language eq 'en') {
    #    return _is_relat_en($tnode);
    #}
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

sub _is_demon_cs_t {
    my ($tnode) = @_;
    return ($tnode->t_lemma eq "ten");
}

sub _is_demon_cs_a {
    my ($anode) = @_;
    return ($anode->lemma eq "ten");
}

1;

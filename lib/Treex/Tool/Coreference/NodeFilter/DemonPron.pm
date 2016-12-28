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

sub _is_demon_cs_t {
    my ($tnode) = @_;
    return ($tnode->t_lemma eq "ten");
}

sub _is_demon_cs_a {
    my ($anode) = @_;
    return ($anode->lemma eq "ten");
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

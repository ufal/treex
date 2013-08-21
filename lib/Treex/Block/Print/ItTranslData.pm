package Treex::Block::Print::ItTranslData;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub _get_aligned_nodes {
    my ($self, $tnode) = @_;

    my ($aligns, $type) = $tnode->get_aligned_nodes;
    my @aligned_from = ();
    if ($aligns && $type) {
        @aligned_from = map {$aligns->[$_]} 
            grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    }
    my @aligned_to = grep {!$_->is_aligned_to($tnode, 'monolingual')} $tnode->get_referencing_nodes('alignment');

    return (@aligned_from, @aligned_to);
}

sub get_class {
    my ($self, $tnode) = @_;
    my @aligned = $self->_get_aligned_nodes($tnode);
    my $class = "<" . (join ":", map {$_->t_lemma} @aligned) . ">";
    return $class;
}

sub _get_nada_refer {
    my ($self, $tnode) = @_;
    my $refer = $tnode->wild->{'referential'};
    return '__UNDEF__' if (!defined $refer);
    return $refer;
}

sub _get_parent_lemma {
    my ($self, $tnode) = @_;
    my $par = $tnode->get_parent;
    if ($par->is_root) {
        return "__ROOT__";
    }
    return $par->t_lemma;
}

sub get_features {
    my ($self, $tnode) = @_;

    my %feats = ();

    ######### FEATURES #############

    $feats{nada_refer} = $self->_get_nada_refer($tnode);
    $feats{par_lemma} = $self->_get_parent_lemma($tnode);
    # TODO:many more features

    ###############################

    return map {$_ . "=" . $feats{$_}} keys %feats;
}

sub process_tnode {
    my ($self, $tnode) = @_;
    
    return if ($tnode->t_lemma ne "#PersPron");

    # TRANSLATION OF "IT" - can be possibly left out => translation of "#PersPron"
    my $anode = $tnode->get_lex_anode;
    return if (!$anode || ($anode->lemma ne "it"));

    my $class = $self->get_class($tnode);
    my @features = $self->get_features($tnode);

    print $class . "\t" . (join " ", @features) . "\n";
}

1;

# TODO POD

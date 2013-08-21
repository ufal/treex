package Treex::Block::Print::ItTranslData;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'data_type' => ( isa => enum([qw/pcedt czeng/]), is => 'ro', required => 1, default => 'pcedt' );

sub _get_aligned_nodes_pcedt {
    my ($self, $tnode) = @_;

    my ($t_csrefs, $t_has_enref) = $self->_csrefs_from_ensrc($tnode);
    
    return ($t_csrefs, undef) if (!defined $t_has_enref);
    return ([], undef) if ($t_has_enref);
        
    my $anode = $tnode->get_lex_anode;
    my ($a_csrefs, $a_has_enref) = $self->_csrefs_from_ensrc($anode);
    
    log_warn "NO_A_MONOALIGN: this should not happen (" . $tnode->get_address . ")\n" if (defined $a_has_enref && ($a_has_enref == 0));

    return (undef, $a_csrefs);

}

sub _csrefs_from_ensrc {
    my ($self, $ensrc) = @_;
    
    my @enrefs = grep {$_->is_aligned_to($ensrc, 'monolingual')} $ensrc->get_referencing_nodes('alignment');
    return ([], 0) if ( @enrefs == 0 );
    
    my ($aligns, $type) = $enrefs[0]->get_aligned_nodes;
    return ([], 1) if (!$aligns || !$type);
        
    my @csrefs = map {$aligns->[$_]} grep {$type->[$_] ne 'monolingual'} (0 .. @$aligns-1);
    return (\@csrefs);
}

sub _get_aligned_nodes_czeng {
    my ($self, $tnode) = @_;

    my @cs_src = grep {!$_->is_aligned_to($tnode, 'monolingual')} $tnode->get_referencing_nodes('alignment');
    return @cs_src;
}

sub get_class_pcedt {
    my ($self, $tnode) = @_;

    my $class;

    my ($aligned_t, $aligned_a) = $self->_get_aligned_nodes_pcedt($tnode);
    if ($aligned_t) {
        $class = "<" . (join ":", map {$_->t_lemma} @$aligned_t) . ">";
    } elsif ($aligned_a) {
        $class = "<alemmas=<" . (join ":", map {$_->lemma} @$aligned_a) . ">>";
    }
    return $class;
}

sub get_class_czeng {
    my ($self, $tnode) = @_;
    my @aligned = $self->_get_aligned_nodes_czeng($tnode);
    my $class = "<" . (join ":", map {$_->t_lemma} @aligned) . ">";
    return $class;
}

sub get_class {
    my ($self, $tnode) = @_;
    
    if ($self->data_type eq 'pcedt') {
        return $self->get_class_pcedt($tnode);
    } else {
        return $self->get_class_czeng($tnode);
    }
    #print STDERR "CLASS: $class; " . $tnode->get_address . "\n";
    #return $class;
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

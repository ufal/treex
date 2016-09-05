package Treex::Block::T2A::EU::AddAuxVerbTense;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my @synthetic = ('egon', 'izan', 'ukan', 'ezan', 'edin', 'esan');

sub process_tnode {
    my ( $self, $tnode ) = @_;

    #EU nodoaren wild zatia eskuratu baldin badu, bestela EN-ekoa
    my $src_t_node = $tnode->src_tnode or return;

    my $tense = ($tnode->wild->{tense} || "");
    if ($tense eq "" )
    {
    	$tense = $src_t_node->wild->{tense} or return;
    }

    return if (($tnode->gram_verbmod || "") eq "imp");
    
    if (($tnode->gram_sempos || "") eq 'v' && ($src_t_node->parent->gram_sempos || "") ne 'v')
    {
    	my $anode = $tnode->get_lex_anode() or return;

	my $semchild = $anode;
	#if (defined $tense->{cont} || defined $tense->{fut}) {
	if (!(grep {$tnode->t_lemma eq $_} @synthetic) || defined $tense->{cont} || defined $tense->{fut}) {
	    my $aux_lemma = $self->is_transitive($tnode) ? 'ukan' : 'izan';
	    $semchild = $anode->create_child({
		'clause_number' => $anode->clause_number,
		'lemma' => $anode->lemma});
	
	    #$semchild->set_lemma($self->verb_lemma($anode->lemma)) if ($anode->iset->pos =~ /^(adj|noun)$/);
	    
	    $anode->set_lemma($aux_lemma);
	    $anode->set_iset('pos' => 'verb', 'verbtype' => 'aux');
	    $anode->set_morphcat_pos('V');
	    $anode->set_afun('AuxV');

	    $semchild->reset_morphcat();
	    $semchild->set_morphcat_pos('V');
	    $semchild->set_afun('AuxV');
	    $semchild->set_iset('pos' => 'verb', 'aspect' => 'imp');
	    $semchild->shift_before_node($anode);
	    $tnode->add_aux_anodes($semchild);
	}

	if (defined $tense->{fut}) {
	    $semchild->set_iset('aspect' => 'pro');
	}
	
	if (defined $tense->{past} && $semchild) {
	    $semchild->set_iset('aspect' => 'perf');
	}
	
	#ex : 'jan dut' --> 'jaten ari naiz' bilakatzen da
	if (defined $tense->{cont}) {
	    #log_info($anode->id);
	    $anode->set_lemma('izan');
	    $anode->set_iset('absnumber' => '', 'absperson' => '');

	    my $child = $anode->create_child({'clause_number' => $anode->clause_number,
		'form' => 'ari', 'lemma' => 'ari'});
	    $child->reset_morphcat();
	    $child->set_morphcat_pos('V');
	    $child->set_afun('AuxV');
	    $child->set_iset('pos' => 'verb');
	    $child->shift_before_node($anode);
	    $tnode->add_aux_anodes($child);

	    $child->set_form("aritu") if ($tense->{pres} && $tense->{perf});
	    $child->set_form("aritua") if ($tense->{pres} && $tense->{perf} && $anode->iset->number eq 'sing');
	    $child->set_form("arituak") if ($tense->{pres} && $tense->{perf} && $anode->iset->number eq 'plur');
	}

	$anode->set_iset('tense', 
			 defined $tense->{pres} ? 'pres' : 
			 defined $tense->{past} ? 'past' : 
			 defined $tense->{fut} ? 'pres' : 
			 "");
    }
    return;
};

sub verb_lemma {
    my ($self, $lemma) = @_;

    $lemma =~ s/([^n])$/$1tu/;
    $lemma =~ s/n$/ndu/;
    
    return "$lemma";
}

sub is_transitive {
    my ($self, $tnode) = @_;

    return 1 if ( any { $_->formeme =~ /^n:\[erg\]/ } $tnode->get_children() );
    return 1 if (($tnode->get_lex_anode()->lemma || "") eq "nahi");
    
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddAuxVerbTense

=head1 DESCRIPTION

Add auxiliary expression for tense information in the wild feature .

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

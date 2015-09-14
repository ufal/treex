package Treex::Block::T2A::ES::AddAuxVerbTense;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    #ES nodoaren wild zatia eskuratu baldin badu, bestela EN-ekoa
    my $src_t_node = $tnode->src_tnode or return;

    my $tense = ($tnode->wild->{tense} || "");
    if ($tense eq "" )
    {
	$tense = $src_t_node->wild->{tense} or return;
    }

    if (($src_t_node->parent->gram_sempos || "") ne 'v')
    {
	my $anode = $tnode->get_lex_anode() or return;
	
	#ex : canto --> estoy cantando bilakatzen da
	if (($tnode->gram_sempos || "") eq 'v' && defined $tense->{cont})
	{
	    my $child = $anode->create_child({
		'clause_number' => $anode->clause_number,
		'lemma' => $anode->lemma,
		'iset/pos' => 'verb',
		'iset/verbform' => 'ger'
					     });
	    $anode->set_lemma('estar');
	    $child->reset_morphcat();
	    $child->set_morphcat_pos('V');
	    $child->set_afun('AuxV');
	    $child->shift_after_node($anode);
	    $tnode->add_aux_anodes($child);
	    
	}
	#ex : estamos --> hemos estado bilakatzen da
	if (($tnode->gram_sempos || "") eq 'v' && (defined $tense->{perf} || ($tense->{modal} && $tense->{past})))
	{
	    my $child = $anode->create_child({
		'clause_number' => $anode->clause_number,
		'lemma' => $anode->lemma,
		'iset/pos' => 'verb',
		'iset/verbform' => 'part',
		'iset/tense' => 'past'
					     });
	    $anode->set_lemma('haber');
	    $child->reset_morphcat();
	    $child->set_morphcat_pos('V');
	    $child->set_afun('AuxV');
	    $child->shift_after_node($anode);
	    $tnode->add_aux_anodes($child);
	}

	$anode->set_iset('tense', 
			 defined $tense->{pres} ? 'pres' : 
			 defined $tense->{past} ? 'past' : 
			 defined $tense->{fut} ? 'fut' : 
			 "");
	#### cdn && modal -> pres batzutan eta cdn batzutan modalaren arabera
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddAuxVerbTense

=head1 DESCRIPTION

Add auxiliary expression for tense information in the wild feature .

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

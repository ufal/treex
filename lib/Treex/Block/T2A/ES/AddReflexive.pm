package Treex::Block::T2A::ES::AddReflexive;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    #comer_se, quedar_se motako aditzetan dagokion hitza gehitzen da, "me, se, te, nos..."
    if ($tnode->t_lemma =~ /^(.+)_se$/)
    {
	my $lemma = $1;
        my $anode = $tnode->get_lex_anode() or return;
	$anode->set_lemma($lemma);

	my $num = "sg";
	my $pers = "3";
	my @children = $tnode->get_children();
	foreach my $child (@children)
	{
	    if ($child->formeme =~ /n:subj/)
	    {
		$num = ($child->gram_number || "sg");
		$pers = ($child->gram_person || "3");
		last;
	    }
	}

	my $form;
	if ($num eq 'sg')
	{
	    if ($pers eq '1') { $form = 'me'; }
	    if ($pers eq '2') { $form = 'te'; }
	    if ($pers eq '3') { $form = 'se'; }
	}
	elsif ($num eq 'pl')
	{
	    if ($pers eq '1') { $form = 'nos'; }
	    if ($pers eq '2') { $form = 'os'; }
	    if ($pers eq '3') { $form = 'se'; }
	}

        my $child = $anode->create_child({
	    'afun' => 'Obj',
	    'form' => $form,
            'lemma' => $form
        });
	$child->iset->add('person' => $pers,
			  'pos' => 'noun',
			  'prontype' => 'prn');
        $child->shift_before_node($anode);	
	$tnode->add_aux_anodes($child);

	print STDERR "AddReflexive: " . $tnode->t_lemma . " ($lemma + $form): $num - $pers\n";
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::ES::AddReflexive

=head1 DESCRIPTION

Add reflexive pronoun to reflexive verbs. 

=head1 AUTHOR

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

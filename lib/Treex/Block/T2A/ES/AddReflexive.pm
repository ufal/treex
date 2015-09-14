package Treex::Block::T2A::ES::AddReflexive;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    #comer_se, quedar_se motako aditzetan dagokion hitza gehitzen da, "me, se, te, nos..."
    if ($tnode->t_lemma =~ /.+_se$/)
    {
        my $anode = $tnode->get_lex_anode() or return;
	my $num;
	my $pers;
	my @children = $tnode->get_children();
	foreach my $child (@children)
	{
	    if ($child->formeme =~ /n:subj/)
	    {
		$num = ($child->gram_number || "");
		$pers = ($child->gram_person || "");
		last;
	    }
	}
	if ($pers eq "")
	{ $pers = '3'; }

	my $lemma;
	if ($num eq 'sg')
	{
	    if ($pers eq '1') { $lemma = 'me'; }
	    if ($pers eq '2') { $lemma = 'te'; }
	    if ($pers eq '3') { $lemma = 'se'; }
	}
	elsif ($num eq 'pl')
	{
	    if ($pers eq '1') { $lemma = 'nos'; }
	    if ($pers eq '2') { $lemma = 'os'; }
	    if ($pers eq '3') { $lemma = 'se'; }
	}

        my $child = $anode->create_child({
	    afun => 'Obj',
	    form => $lemma,
            lemma => $lemma
        });
	$child->set_iset(person => $pers,
			 pos => 'noun',
			 prontype => 'prn',);
        $child->shift_before_node($anode);
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

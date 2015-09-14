package Treex::Block::A2T::ES::FixReflexiveVerbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $node ) = @_;

    #behar duten aditzen lema bukaeran "_se" gehitzen da
    if ($node->gram_sempos && $node->gram_sempos eq 'v')
    {
    	my $found = 0;
    	my @children = $node->get_children();
	my $objchild;
      FIRST_LOOP:
	foreach my $i (0..$#children)
	{
	    $objchild = $children[$i];
	    if ($objchild->formeme eq 'n:obj')
	    {
		if ($objchild->gram_sempos eq 'n.pron.def.pers')
		{
		    if (($objchild->gram_person || "") eq '3' && $objchild->t_lemma ne 'se')
		    { next FIRST_LOOP; }
		    foreach my $j (0..$#children)
		    {
			my $subchild = $children[$j];
			if ($subchild->formeme eq 'n:subj')
			{   
			    if ((($subchild->gram_number && $objchild->gram_number && ($subchild->gram_number eq $objchild->gram_number)) ||
				 !$subchild->gram_number ||
				 !$objchild->gram_number) &&
				(($subchild->gram_person && $objchild->gram_person && $subchild->gram_person eq $objchild->gram_person) ||
				 ($subchild->gram_person && $subchild->gram_person eq '3' && !$objchild->gram_person) ||
				 ($objchild->gram_person && $objchild->gram_person eq '3' && !$subchild->gram_person)
				))
			    {
				my $new_tlemma = $node->t_lemma . '_se';
				$node->set_t_lemma($new_tlemma);
				$objchild->remove;
				$found = 1;
				last FIRST_LOOP;
			    }
			}
		    }
		}
	    }
	}
	
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::ES::FixReflexiveVerbs

=head1 DESCRIPTION

Corrects the t_lemma feature to reflexive verbs. Thus, 'tirar' ('throw') 
and 'tirar_se' ('jump') can be distinguish 

=head1 AUTHOR

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

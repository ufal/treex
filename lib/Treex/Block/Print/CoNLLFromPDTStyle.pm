package Treex::Block::Print::CoNLLFromPDTStyle;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# similar to the constant defined in Treex::Block::Write::ConllLike
# except that it is defined in the reverse order for convenience.
Readonly my %positions_feats => (
    #"1"	=>	"POS",
    #"2"	=>	"SubPOS",
    "3"	=>	"Gen",
    "4"	=>	"Num",
    "5"	=>	"Cas",
    "6"	=>	"PGe",
    "7"	=>	"PNu",
    "8"	=>	"Per",
    "9"	=>	"Ten",
    "10"	=>	"Gra",
    "11"	=>	"Neg",
    "12"	=>	"Voi",
    #"13"	=>	"Unused",
    #"14"	=>	"Unused",
    "15"	=>	"Var"
); 

sub process_atree {
    my $self = shift;
    my $tree = shift;
    my @nodes = $tree->get_descendants({'ordered' => 1});
    foreach my $n (@nodes) {
    	if (length($n->tag) != 15) {
    		log_fatal("The length of the tag is not 15");
    	}
    	my @conll_line = ();
		# 1. ID
		$conll_line[0] = $n->ord;		
		# 2. FORM
		$conll_line[1] = $n->form;
		# 3. LEMMA
		if (defined $n->lemma) {
			$conll_line[2] = $n->lemma;			 
		}
		else {
			$conll_line[2] = $n->form;
		}
		# 4. CPOSTAG (only the 1st position of the pdt tag)
		$conll_line[3] = substr $n->tag, 0, 1;
		# 5. POSTAG (only the 1st 2 positions)
		$conll_line[4] = substr $n->tag, 0, 2;
		# 6. FEATS
		my $feats = '_';
		my @f;
		foreach my $i (keys %positions_feats) {
			my $pval = substr $n->tag, $i-1, 1;
			if ($pval ne '-') {
				push @f, $positions_feats{$i} . "=" . $pval;				
			}
		}
		$feats = join("|", @f) if scalar @f > 0;
		$conll_line[5] = $feats;
		# 7. HEAD 
		$conll_line[6] = $n->get_parent->ord;
		# 8. DEPREL (afun)
		if ( defined $n->afun ) {
			$conll_line[7] = $n->afun;	
		}
		else {
			$conll_line[7] = '_';
		}
		# 9. PHEAD
		$conll_line[8] = '_';
		# 10. PDEPREL
		$conll_line[9] = '_';
		# print the conll line
		print join("\t", @conll_line) . "\n";		
    }
    print "\n";
}

1;

__END__

=head1 NAME

Treex::Block::Print::CoNLLFromPDTStyle - Prints a-tree in CoNLL format.

=head1 DESCRIPTION

Given an a-tree that uses PDT style tags (15-positions) and afuns, this block prints the a-trees in CoNLL format. The CoNLL columns - "CPOSTAG POSTAG FEATS" 
are determined solely from the positional tag. CPOSTAG is the 1st position in the positional tag. POSTAG is the first 2 positions together in the positional tag.
FEATS are determined from the remaining part of the positional tag. DEPREL corresponds to 'afun' attribute of the a-node.  

=head1 SEE ALSO

L<Treex::Block::Write::CoNLLX>,
L<Treex::Block::Write::ConllLike>
 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE 

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
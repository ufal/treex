package Treex::Block::Print::FormemeSemposMismatch;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

#extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($tnode->formeme and $tnode->formeme =~ /^(n|v|adj|adv)/) {
	my $pos_from_formeme = $1;

	if ($tnode->gram_sempos and $tnode->gram_sempos =~ /^(n|v|adj|adv)/) {

	    my $pos_from_sempos = $1;

	    if ($pos_from_formeme ne $pos_from_sempos) {

		my $src_tnode = $tnode->src_tnode;
		my ($src_tlemma, $src_formeme) = ('','');
		if ($src_tnode) {
		    $src_tlemma = $src_tnode->t_lemma;
		    $src_formeme = $src_tnode->formeme;

		}

		say join "\t", ( $tnode->gram_sempos,
				 $tnode->formeme,
#				 $pos_from_sempos,
#				 $pos_from_formeme,
				 $tnode->t_lemma,
				 $src_tlemma,
				 $src_formeme,
				 $tnode->get_address
		);

	    }
	}
    }
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::FormemeSemposMismatch

=head1 DESCRIPTION

Independent transfer of formemes and lemmas might lead to mismatches that cannot be
resolved correctly in the synthesis phrase. Let's study the mismatches.

=head1 AUTHORS 

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::W2A::FR::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
	
	# pad with spaces for easier regexps
	$sentence =~ s/^(.*)$/ $1 /;
	
	# d' où, j' ai, l' homme, m' a, n' est, s' est, t' ont (but aujourd'hui)
    $sentence =~ s/((^|\s)[djlmnst][\'’])([àaeéiyouh][^\s]*) / $1 $3 /gi;	
	
	# qu' il, lorsqu' il, quoiqu' il, jusqu' à, presqu' un (but presqu'île)		
	$sentence =~ s/ ((lorsqu|quoiqu|jusqu|presqu|qu)[\'’])([àaeéiyou][^\s]*) / $1 $3 /gi;
	
	# avons-nous, ai -je, a -t-il, a -t-elle, aime -moi (but ci-dessus, moi-même) for hyphen-minus and dash
	$sentence =~ s/ (\p{Letter}+)(([-‒]t)?[-‒](je|tu|il|elle|on|nous|vous|ils|elles|moi|toi)) / $1 $2 /gi;	
	
	# clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^\s*//g;
    $sentence =~ s/\s*$//g;	
	
    return $sentence;
};

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::FR::Tokenize - rule-based tokenization

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens using a series of regexs.
Flat a-tree is built and attributes C<no_space_after> are filled.
This class uses French specific regex rules for tokenization
of contractions like <l'homme, d'un> etc. and 
constructions with hyphen-minus/dash like <ai-je, a-t-elle, aime-moi> etc.

The output is suitable for TreeTagger. 

=head1 AUTHOR

Ivan Šmilauer

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

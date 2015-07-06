package Treex::Block::W2A::JA::FixTagsUD;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;

extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    my $tag = $anode->tag;
	my $new_tag = "X"; # default - whitespace (shouldn't occur)

	# Adjectives
	if ( $tag =~ /^(形容詞|連体詞|形状詞)/ ) {
		$new_tag = "ADJ";

		# 連体詞 (adnominal) can be demonstrative determiner (DET) sometimes
		# $new_tag = "DET" if ...;

		# 形容詞 (adjective) can be tagged as AUX if used as a functional word
		# $new_tag = "AUX" if ...;
	}

	# Adverbs
	$new_tag = "ADV" if ( $tag =~ /^副詞/ );

	# Interjections
	$new_tag = "INTJ" if ( $tag =~ /^感動詞/ );

	# Nouns
	if ( $tag =~ /^(名詞-普通名詞|接頭辞|接尾辞)/ ) {
		$new_tag = "NOUN";

		# 名詞-普通名詞 (common noun) can be sometimes VERB or ADJ depending on the other subtags
		# $new_tag = "VERB" if ...;
		# $new_tag = "ADJ" if ...;
	}

	# Proper Nouns
	$new_tag = "PROPN" if ( $tag =~ /^名詞-固有名詞/ );

	# Verbs
	if ( $tag =~ /^動詞/ ) {
		$new_tag = "VERB";

		# 動詞 (verb) can be tagged as AUX if used as a functional word
		# $new_tag = "AUX" if ...;
	}

	# Auxiliary Verbs
	$new_tag = "AUX" if ( $tag =~ /^助動詞/ );

	# Adpositions
	if ( $tag =~ /^(助詞-格助詞|助詞-係助詞)/ ) {
		$new_tag = "ADP";

		# 助詞 (particle) can be sometimes classified as CONJ, SCONJ or PART
		# $new_tag = "CONJ" if ...;
		# $new_tag = "SCONJ" if ...;
		# $new_tag = "PART" if ...;
	}

	# Coordinating Conjunctions
	$new_tag = "CONJ" if ( $tag =~ /^接続詞/ );

	# Numerals
	$new_tag = "NUM" if ( $tag =~ /^名詞-数詞/ );

	# Particles (which are not already classified as ADP, CONJ or SCONJ)
	# TODO: Should 助詞-副助詞 (adverbial particle) be here?
	$new_tag = "PART" if ( $tag =~ /^(助詞-副助詞|助詞-終助詞)/ && $new_tag !~ /^(ADP|CONJ|SCONJ)/ );

	# Pronouns
	$new_tag = "PRON" if ( $tag =~ /^代名詞/ );

	# Subordinating Conjunctions
	$new_tag = "SCONJ" if ( $tag =~ /^(助詞-接続助詞|助詞-準体助詞)/ );

	# Punctuation (period, comma, open/close bracket)
	if ( $tag =~ /^補助記号/ ) {
		$new_tag = "PUNCT";

		# Other are tagged as SYM
		# $new_tag = "SYM" if ...;
	}

	$new_tag = "SYM" if ( $tag =~ /^記号/ );

	$anode->set_tag($new_tag);

    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::FixTagsUD - Fix tags produced by MeCab taggers so they follow L<Universal Dependencies|http://universaldependencies.github.io/docs/#language-ja> standard

=head1 DESCRIPTION

In this block, Unidic tags (and possibly Ipadic to some degree) are converted to tagset
defined by Universal Dependencies standard.

=head1 SEE ALSO

L<Universal Dependencies Homepage|http://universaldependencies.github.io/docs/>

L<General Principles|http://universaldependencies.github.io/docs/ja/overview/morphology.html>

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

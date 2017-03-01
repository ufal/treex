package Treex::Block::W2A::JA::RomanizeTags;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;

use Lingua::JA::Romanize::Japanese;

extends 'Treex::Core::Block';

# TODO: Something like this should be used in the future
sub romanize_rest {
	my ( $tag ) = @_;
	my $conv = Lingua::JA::Romanize::Japanese->new();
	my @new_tag = ();

	foreach my $word (split /\-/, $tag) {
		my $romanized = $word;
		$romanized = $conv->chars( $word ) if ( $word =~ /[^a-zA-Zōū]/);
		$romanized =~ s/ //g;
		push @new_tag, $romanized;
	}

    return join("-", @new_tag);
}



# When we use UniDic dictionary there are many subtags which are not covered by this, however it would be nice to romanize them too
sub process_anode {
    my ( $self, $anode ) = @_;
    my ( $tag ) = $anode->tag;

            $tag =~ s{アルファベット}{Alphabet};
            $tag =~ s{ナイ形容詞語幹}{NaiKeiyōshiGokan};
            $tag =~ s{形容動詞語幹}{KeiyōdōshiGokan};
            $tag =~ s{動詞非自立的}{DōshiHiJiritsuTeki};
            $tag =~ s{助詞類接続}{JoshiRuiSetsuzoku};
            $tag =~ s{引用文字列}{InYōmojiretsu};
            $tag =~ s{形容詞接続}{KeiyōshiSetsuzoku};
            $tag =~ s{助動詞語幹}{JodōshiGokan};
            $tag =~ s{接続詞的}{SetsuzokushiTeki};
            $tag =~ s{副詞可能}{FukushiKanō};
            $tag =~ s{固有名詞}{Koyūmeishi};
            $tag =~ s{サ変接続}{SahenSetsuzoku};
            $tag =~ s{並立助詞}{Heiritsujoshi};
            $tag =~ s{接続助詞}{SetsuzokuJoshi};
            $tag =~ s{動詞接続}{DōshiSetsuzoku};
            $tag =~ s{名詞接続}{MeishiSetsuzoku};
            $tag =~ s{代名詞}{Daimeishi};
            $tag =~ s{形容詞}{Keiyōshi};
            $tag =~ s{連体詞}{Rentaishi};
            $tag =~ s{助動詞}{Jodōshi};
            $tag =~ s{接続詞}{Setsuzokushi};
            $tag =~ s{非自立}{HiJiritsu};
            $tag =~ s{フィラー}{Filler};
            $tag =~ s{感動詞}{Kandōshi};
            $tag =~ s{その他}{Sonohoka};
            $tag =~ s{接頭詞}{SettōShi};
            $tag =~ s{係助詞}{Keijoshi};
            $tag =~ s{副助詞}{FukuJoshi};
            $tag =~ s{副詞化}{FukushiKa};
            $tag =~ s{格助詞}{Kakujoshi};
            $tag =~ s{終助詞}{Shūjoshi};
            $tag =~ s{連体化}{RentaiKa};
            $tag =~ s{数接続}{SūSetsuzoku};
            $tag =~ s{括弧閉}{Kakko閉};
            $tag =~ s{括弧開}{KakkoHiraki};
            $tag =~ s{助数詞}{Josūshi};
            $tag =~ s{記号}{Kigō};
            $tag =~ s{動詞}{Dōshi};
            $tag =~ s{接尾}{Setsubi};
            $tag =~ s{自立}{Jiritsu};
            $tag =~ s{一般}{Ippan};
            $tag =~ s{副詞}{Fukushi};
            $tag =~ s{助詞}{Joshi};
            $tag =~ s{名詞}{Meishi};
            $tag =~ s{特殊}{Tokushu};
            $tag =~ s{間投}{MaTō};
            $tag =~ s{特殊}{Tokushu};
            $tag =~ s{句点}{Kuten};
            $tag =~ s{空白}{Kūhaku};
            $tag =~ s{読点}{Tōten};
            $tag =~ s{地域}{Chiiki};
            $tag =~ s{連語}{Rengo};
            $tag =~ s{組織}{Soshiki};
            $tag =~ s{人名}{Jinmei};
            $tag =~ s{縮約}{Shukuyaku};
            $tag =~ s{引用}{In'yō};
            $tag =~ s{数}{Kazu};
            $tag =~ s{国}{Kuni};
            $tag =~ s{姓}{Sei};

    $anode->set_tag(romanize_rest($tag));

    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::RomanizeTags - Conversion of IPADIC (and possibly other) tags from kanji to romaji.

=head1 DESCRIPTION

POS tags are romanized for each node via hardcoded substitutions. After that,
rest of the kanji is converted via L<Lingua::JA::Romanize::Japanese|http://mecab.googlecode.com/svn/trunk/mecab/doc/index.html>.

=head1 TODO

Get rid of the hard coded part (use only the converter).

The converter lists all possible romanizations (if available). Figure out how to pick the correct one.

Instead of romanization replace tags with appropriate abbreviation for easier
work. This can possibly be implemented in L< Lingua::Interset|http://search.cpan.org/~zeman/Lingua-Interset-2.041/lib/Lingua/Interset.pm>.

=head1 SEE ALSO

L<Lingua::JA::Romanize::Japanese|http://mecab.googlecode.com/svn/trunk/mecab/doc/index.html> - Romanization of Japanese language

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

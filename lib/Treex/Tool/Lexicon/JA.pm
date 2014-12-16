package Treex::Tool::Lexicon::JA;
use Treex::Core::Common;
use autodie;
use utf8;

# list is incomplete, we list both kanji and hiragana representation if possible
my @PERS_PRONOUNS = 
  qw(私 我 吾 我が 俺 僕 儂 自分 家 内 貴方 貴男 貴女 お宅 御宅 お前 手前 貴様 君 貴下 貴官 御社 貴社
     あの方 あの人 奴 此奴 其奴 彼奴 彼 彼女 我々 我等 弊社 我が社 彼等 わたし わたくし われ わが おれ
     ぼく わし じぶん あたい あたし あたくし うち おいら おら わて あなた あんた おたく おまえ てめえ
     てまえ きさま きみ きか きかん おんしゃ きしゃ あのかた あのひと やつ こいつ こやつ そいつ そやつ
     あいつ あやつ かれ かのじょ われわれ われら へいしゃ わがしゃ かれら);
my %IS_PERS_PRON;

foreach my $lemma (@PERS_PRONOUNS) {
  $IS_PERS_PRON{$lemma} = 1;  
};

sub is_pers_pron {
  my ($lemma) = @_;
  return $IS_PERS_PRON{$lemma};
};

my %NUMBER_FOR_NUMERAL = (
  '零'  => '0',
  '一'  => '1',
  '二'  => '2',
  '三'  => '3',
  '四'  => '4',
  '五'  => '5',
  '六'  => '6',
  '七'  => '7',
  '八'  => '8',
  '九'  => '9',
  '十'  => '10',
  '百'  => '100',
  '千'  => '1000',
  '万'  => '10000',
);

sub number_for {
  my ($lemma) = @_;
  return $lemma if $lemma =~ /^\d+$/;
  return $NUMBER_FOR_NUMERAL{$lemma};
};

my %NUMBER_OF_MONTH = (
  '一月'    => '1',
  '二月'    => '2',
  '三月'    => '3',
  '四月'    => '4',
  '五月'    => '5',
  '六月'    => '6',
  '七月'    => '7',
  '八月'    => '8',
  '九月'    => '9',
  '十月'    => '10',
  '十一月'  => '11',
  '十二月'  => '12',
);

sub number_of_month {
    my ($lemma) = @_;
    return $NUMBER_OF_MONTH{$lemma};
}

my %NUMBER_OF_DAY = (
  '月曜日'  => '1',
  '火曜日'  => '2',
  '水曜日'  => '3',
  '木曜日'  => '4',
  '金曜日'  => '5',
  '土曜日'  => '6',
  '日曜日'  => '7',
);

sub number_of_day {
  my ($lemma) = @_;
  return $NUMBER_OF_DAY{$lemma};
};

sub truncate_lemma {
    return @_;
};

1;

__END__

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::JA

=head1 SYNOPSIS

use Treex::Tool::Lexicon::JA;

if ( Treex::Tool::Lexicon::JA::is_pers_pron('私') ) {
    print "OK\n";
}

=head1 DESCRIPTION

This module should include support for miscellaneous queries
involving Japanese lexicon.

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


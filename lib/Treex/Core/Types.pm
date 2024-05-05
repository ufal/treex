package Treex::Core::Types;

use strict;
use warnings;
use utf8;
use Moose::Util::TypeConstraints;

subtype 'Treex::Type::NonNegativeInt'
    => as 'Int'
    => where { $_ >= 0 }
=> message {"$_ isn't non-negative"};

subtype 'Treex::Type::Selector'
    => as 'Str'
    => where {m/^[a-z\d]*$/i}
=> message {"Selector must =~ /^[a-z\\d]*\$/i. You've provided $_"};    #TODO: this message is not printed

subtype 'Treex::Type::Layer'
    => as 'Str'
    => where {m/^[ptan]$/i}
=> message {"Layer must be one of: [P]hrase structure, [T]ectogrammatical, [A]nalytical, [N]amed entities, you've provided $_"};

sub layers {
    return qw(A T P N);
}

subtype 'Treex::Type::Message'                                          #nonempty string
    => as 'Str'
    => where { $_ ne q{} }
=> message {'Message must be nonempty'};

#preparation for possible future constraints
subtype 'Treex::Type::Id'
    => as 'Str';

# TODO: Should this be named ZoneCode or ZoneLabel?
subtype 'Treex::Type::ZoneCode'
    => as 'Str'
    => where { my ( $l, $s ) = split /_/, $_; is_lang_code($l) && ( !defined $s || $s =~ /^[a-z\d]*$/i ) }
=> message {'ZoneCode must be LangCode or LangCode_Selector, e.g. "en_src"'};

# ISO 639-1 language code with some extensions from ISO 639-2, 639-3 and ISO 15924 (script names).
# Added code for Modern Greek which comes under ISO 639-3 (but normally it is encoded using ISO 639-1 'el').
use Locale::Language;
my %EXTRA_LANG_CODES = (
    'abq'     => "Abaza",
    'aeb'     => "Tunisian Arabic",
    'aii'     => "Assyrian",
    'ajp'     => "South Levantine Arabic",
    'akk'     => "Akkadian",
    'aln'     => "Gheg", # Albanian
    'apu'     => "Apurina", # Apurinã
    'aqz'     => "Akuntsu",
    'arr'     => "Karo",
    'azz'     => "Highland Puebla Nahuatl",
    'bal'     => "Balochi",
    'bar'     => "Bavarian",
    'bav'     => "Babungo",
    'bej'     => "Beja",
    'bho'     => "Bhojpuri",
    'bor'     => "Bororo",
    'bxr'     => "Buryat",
    'bzd'     => "Bribri",
    'ceb'     => "Cebuano",
    'cgg'     => "Kiga",
    'ckb'     => "Sorani", # Central Kurdish
    'ckt'     => "Chukchi",
    'cop'     => "Coptic",        # ISO 639-2
    'cpg'     => "Cappadocian",
    'cux'     => "Cuicatec",
    'dar'     => "Dargwa",
    'dbl'     => "Dyirbal",
    'dsb'     => "Lower Sorbian",
    'egy'     => "Egyptian",
    'ell'     => "Modern Greek",  # ISO 639-3
    'eme'     => "Teko",
    'ess'     => "Yupik",
    'frm'     => "Middle French",
    'fro'     => "Old French",
    'gcd'     => "Yukulta",
    'got'     => "Gothic",        # ISO 639-2
    'gqa'     => "Ga",
    'grc'     => "Ancient Greek", # ISO 639-2
    'gsw'     => "Swiss German",
    'gub'     => "Guajajara",
    'gun'     => "Mbya Guarani",
    'hbo'     => "Ancient Hebrew",
    'hit'     => "Hittite",       # ISO 639-2
    'hsb'     => "Upper Sorbian",
    'hak'     => "Hakka",
    'hil'     => "Hiligaynon",
    'huv'     => "Huave",
    'hyw'     => "Western Armenian",
    'ifb'     => "Batad Ifugao",
    'jaa'     => "Madi",
    'kaa'     => "Karakalpak",
    'kab'     => "Kabyle",
    'kfm'     => "Khunsari",
    'kfz'     => "Koromfe",
    'kmr'     => "Kurmanji", # Northern Kurdish
    'koi'     => "Komi Permyak",
    'kpv'     => "Komi Zyrian",
    'krl'     => "Karelian",
    'ku-latn' => "Kurdish in Latin script",
    'ku-arab' => "Kurdish in Arabic script",
    'ku-cyrl' => "Kurdish in Cyrillic script",
    'lad'     => "Ladino",
    'laj'     => "Lango",
    'lez'     => "Lezgian",
    'lij'     => "Ligurian",
    'ltg'     => "Latgalian",
    'lus'     => "Mizo",
    'lzh'     => "Classical Chinese",
    'lzz'     => "Laz",
    'mag'     => "Magahi",
    'mdf'     => "Moksha",
    'mga'     => "Middle Irish",
    'mjl'     => "Mandyali",
    'mov'     => "Mojave",
    'mpu'     => "Makurap",
    'mul'     => "multiple languages", # ISO 639-2 code
    'mxx'     => "Mauka",
    'myu'     => "Munduruku", # Mundurukú
    'myv'     => "Erzya",
    'nan'     => "Taiwanese",
    'nap'     => "Neapolitan",
    'naq'     => "Khoekhoe",
    'nci'     => "Classical Nahuatl",
    'ndg'     => "Ndengeleko",
    'nds'     => "Low Saxon",
    'nhi'     => "Western Sierra Puebla Nahuatl",
    'nyn'     => "Nkore",
    'nyq'     => "Nayini",
    'ojp'     => "Old Japanese",
    'olo'     => "Livvi", # Olonets Karelian
    'orv'     => "Old Russian",
    'osx'     => "Old Saxon",
    'ota'     => "Ottoman Turkish",
    'otk'     => "Old Turkish",
    'pad'     => "Paumari",
    'pap'     => "Papiamento",
    'pbv'     => "Pnar",
    'pcm'     => "Nigerian Pidgin (Naija)",
    'pgl'     => "Archaic Irish",
    'pnt'     => "Pontic",
    'pra'     => "Prakrit",
    'prx'     => "Purki",
    'rmy'     => "Romany",
    'qaf'     => "Maghrebi Arabic-French", # used in UD code-switching corpora
    'qee'     => "Spanish English",
    'qfn'     => "Frisian-Dutch", # used in UD code-switching corpora
    'qhe'     => "Hindi-English", # used in UD code-switching corpora
    'qpm'     => "Pomak",
    'qtd'     => "Turkish-German", # used in UD code-switching corpora
    'qte'     => "Telugu-English", # used in UD code-switching corpora
    'quc'     => "Kiche",
    'quz'     => "Cusco Quechua",
    'sah'     => "Yakut",
    'say'     => "Zaar",
    'sei'     => "Seri",
    'sga'     => "Old Irish",
    'shp'     => "Shipibo Konibo",
    'sjo'     => "Xibe",
    'sme'     => "North Sami",
    'sms'     => "Skolt Sami",
    'soj'     => "Soi",
    'sux'     => "Sumerian",
    'swl'     => "Swedish Sign Language",
    'tpn'     => "Tupinamba", # Tupinambá
    'und'     => "unknown", # ISO 639-2 code for undetermined/unknown language
    'urb'     => "Kaapor",
    'usp'     => "Uspanteko",
    'vep'     => "Veps",
    'wbp'     => "Warlpiri",
    'xal'     => "Kalmyk",
    'xav'     => "Xavante",
    'xcl'     => "Classical Armenian",
    'xnr'     => "Kangri",
    'xum'     => "Umbrian",
    'yii'     => "Yidiny",
    'yrl'     => "Nheengatu",
    'yue'     => "Cantonese",
    'zmu'     => "Muruwari",
);

my %IS_LANG_CODE = map { $_ => 1 } ( all_language_codes(), keys %EXTRA_LANG_CODES );

subtype 'Treex::Type::LangCode'
    => as 'Str'
    => where { defined $IS_LANG_CODE{$_} }
=> message {'LangCode must be valid ISO 639-1 code. E.g. en, de, cs'};
sub is_lang_code { return $IS_LANG_CODE{ $_[0] }; }

sub get_lang_name {
    my $code = shift;
    return exists $EXTRA_LANG_CODES{$code} ? $EXTRA_LANG_CODES{$code} : code2language($code);
}
1;
__END__

=encoding utf-8

=head1 NAME

Treex::Core::Types - types used in Treex framework

=head1 DESCRIPTION

=head1 TYPES

=over 4

=item Treex::Type::NonNegativeInt

0, 1, 2, ...

=item Treex::Type::Layer

one of: P, T, A, N
case insensitive

=item Treex::Type::Selector

Selector - only alphanumeric characters, may be empty

=item Treex::Type::LangCode

ISO 639-1 code

=item Treex::Type::ZoneCode

Combination of LangCode and Selector, e.g. "en_src"

=item Treex::Type::Message

just nonempty string, future constraints may be set

=item Treex::Type::Id

identifier, prepared for future constraints, now it is any string

=back

=head1 METHODS

=over 4

=item get_lang_name

Returns language name for given LangCode

=item is_lang_code

Checks whether given argument is valid LangCode

=item layers

Returns array of layers available in Treex, now (A, T, P, N)

=back

=head1 AUTHOR

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

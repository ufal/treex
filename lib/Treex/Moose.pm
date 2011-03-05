package Treex::Moose;
use utf8;
use Moose;
use Moose::Exporter;
use Moose::Util::TypeConstraints;
use MooseX::SemiAffordanceAccessor::Role::Attribute;
use MooseX::Params::Validate;
use Treex::Core::Log;
use Treex::Core::Config;
use Treex::Core::Resource;
use List::MoreUtils;
use List::Util;
use Scalar::Util;
use Readonly;
use Data::Dumper;

my ( $import, $unimport, $init_meta ) =
    Moose::Exporter->build_import_methods(
    install         => [qw(unimport init_meta)],
    also            => 'Moose',
    class_metaroles => { attribute => ['MooseX::SemiAffordanceAccessor::Role::Attribute'] },
    as_is           => [
        \&Treex::Core::Log::log_fatal,
        \&Treex::Core::Log::log_warn,
        \&Treex::Core::Log::log_debug,
        \&Treex::Core::Log::log_set_error_level,
        \&Treex::Core::Log::log_info,
        \&List::MoreUtils::first_index,
        \&List::MoreUtils::all,
        \&List::MoreUtils::any,
        \&List::Util::first,
        \&Readonly::Readonly,
        \&Scalar::Util::weaken,
        \&Data::Dumper::Dumper,
        \&MooseX::Params::Validate::pos_validated_list,
        \&Moose::Util::TypeConstraints::enum,
        ]
    );

sub import {
    utf8::import();
    goto &$import;
}

subtype 'Selector'
    => as 'Str'
    => where { m/^[a-z\d]*$/i }
    => message {"Selector must =~ /^[a-z\\d]*\$/i. You've provided $_"}; #TODO: this messege is not printed

subtype 'Layer'
    => as 'Str'
    => where {m/^[ptan]$/i}
=> message {"Layer must be one of: [P]hrase structure, [T]ectogrammatical, [A]nalytical, [N]amed entities, you've provided $_"};

subtype 'Message'                       #nonempty string
    => as 'Str'
    => where { $_ ne '' }
=> message {"Message must be nonempty"};

subtype 'Id'
    => as 'Str';                        #preparation for possible future constraints

# ISO 639-1 language code with some extensions from ISO 639-2
my @LANG_CODES = (

    # major languages
    'en',                               # English
    'de',                               # German
    'fr',                               # French
    'es',                               # Spanish
    'it',                               # Italian
    'ru',                               # Russian
    'ar',                               # Arabic
    'zh',                               # Chinese

    # other Slavic languages
    'cs',                               # Czech
    'sk',                               # Slovak
    'pl',                               # Polish
    'dsb',                              # Lower Sorbian
    'hsb',                              # Upper Sorbian
    'be',                               # Belarusian
    'uk',                               # Ukrainian
    'sl',                               # Slovene
    'hr',                               # Croatian
    'sr',                               # Serbian
    'mk',                               # Macedonian
    'bg',                               # Bulgarian
    'cu',                               # Old Church Slavonic

    # other Germanic languages
    'nl',                               # Dutch
    'af',                               # Afrikaans
    'fy',                               # Frisian
    'lb',                               # Luxemburgish
    'yi',                               # Yiddish
    'da',                               # Danish
    'sv',                               # Swedish
    'no',                               # Norwegian
    'nn',                               # Nynorsk (New Norwegian)
    'fo',                               # Faroese
    'is',                               # Icelandic

    # other Romance and Italic languages
    'la',                               # Latin
    'pt',                               # Portuguese
    'gl',                               # Galician
    'ca',                               # Catalan
    'oc',                               # Occitan
    'rm',                               # Rhaeto-Romance
    'co',                               # Corsican
    'sc',                               # Sardinian
    'ro',                               # Romanian
    'mo',                               # Moldovan (deprecated: use Romanian)

    # Celtic languages
    'ga',                               # Irish
    'gd',                               # Scottish
    'cy',                               # Welsh
    'br',                               # Breton

    # Baltic languages
    'lt',                               # Lithuanian
    'lv',                               # Latvian

    # other Indo-European languages in Europe and Caucasus
    'sq',                               # Albanian
    'el',                               # Greek
    'hy',                               # Armenian

    # Iranian languages
    'fa',                               # Persian
    'ku-latn',                          # Kurdish in Latin script
    'ku-arab',                          # Kurdish in Arabic script
    'ku-cyrl',                          # Kurdish in Cyrillic script
    'os',                               # Ossetic
    'tg',                               # Tajiki (in Cyrillic script)
    'ps',                               # Pashto

    # Indo-Aryan languages
    'ks',                               # Kashmiri (in Arabic script)
    'sd',                               # Sindhi
    'pa',                               # Punjabi
    'ur',                               # Urdu
    'hi',                               # Hindi
    'gu',                               # Gujarati
    'mr',                               # Marathi
    'ne',                               # Nepali
    'or',                               # Oriya
    'bn',                               # Bengali
    'as',                               # Assamese
    'rmy',                              # Romany

    # other Semitic languages
    'mt',                               # Maltese
    'he',                               # Hebrew
    'am',                               # Amharic

    # Finno-Ugric languages
    'hu',                               # Hungarian
    'fi',                               # Finnish
    'et',                               # Estonian

    # other European and Caucasian languages
    'eu',                               # Basque
    'ka',                               # Georgian
    'ab',                               # Abkhaz
    'ce',                               # Chechen

    # Turkic languages
    'tr',                               # Turkish
    'az',                               # Azeri
    'cv',                               # Chuvash
    'ba',                               # Bashkir
    'tt',                               # Tatar
    'tk',                               # Turkmen
    'uz',                               # Uzbek
    'kaa',                              # Karakalpak
    'kk',                               # Kazakh
    'ky',                               # Kyrgyz
    'ug',                               # Uyghur
    'sah',                              # Yakut

    # other Altay languages
    'xal',                              # Kalmyk
    'bxr',                              # Buryat
    'mn',                               # Mongol
    'ko',                               # Korean
    'ja',                               # Japanese

    # Dravidian languages
    'te',                               # Telugu
    'kn',                               # Kannada
    'ml',                               # Malayalam
    'ta',                               # Tamil

    # Sino-Tibetan languages
    'zh',                               # Mandarin Chinese
    'hak',                              # Hakka
    'nan',                              # Taiwanese
    'yue',                              # Cantonese
    'lo',                               # Lao
    'th',                               # Thai
    'my',                               # Burmese
    'bo',                               # Tibetan

    # Austro-Asian languages
    'vi',                               # Vietnamese
    'km',                               # Khmer

    # other languages
    'sw',                               # Swahili
    'eo',                               # Esperanto
    'und',                              # ISO 639-2 code for undetermined/unknown language
);

enum 'LangCode' => @LANG_CODES;
my %IS_LANG_CODE = map { $_ => 1 } @LANG_CODES;
sub is_lang_code { return $IS_LANG_CODE{ $_[0] }; }

1;

=head1 NAME
 
Treex::Moose - shorten the "use" part of your Perl codes

=head1 SYNOPSIS

Write just

 use Treex::Moose;

Instead of

 use utf8;
 use strict;
 use warnings;
 use Moose;
 use Moose::Util::TypeConstraints qw(enum);
 use MooseX::SemiAffordanceAccessor;
 use MooseX::Params::Validate qw(pos_validated_list);
 use Treex::Core::Log;
 use Treex::Core::Config;
 use Treex::Core::Resource;
 use List::MoreUtils qw(all any first_index);
 use List::Util qw(first);
 use Scalar::Util qw(weaken);
 use Readonly qw(Readonly);
 use Data::Dumper qw(Dumper);

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README

package Treex::Moose;
use Moose;
use Moose::Exporter;
use MooseX::SemiAffordanceAccessor::Role::Attribute;
use Treex::Core::Log;
use Treex::Core::Config;
use List::MoreUtils;
use List::Util;
use Scalar::Util;
use Readonly;
use Data::Dumper;

Moose::Exporter->setup_import_methods(
    also            => 'Moose',
    class_metaroles => { attribute => ['MooseX::SemiAffordanceAccessor::Role::Attribute'] },
    as_is           => [
        \&Treex::Core::Log::log_fatal,
        \&Treex::Core::Log::log_warn,
        \&Treex::Core::Log::log_debug,
        \&Treex::Core::Log::log_memory,
        \&Treex::Core::Log::log_set_error_level,
        \&Treex::Core::Log::log_info,
        \&List::MoreUtils::first_index,
        \&List::MoreUtils::all,
        \&List::MoreUtils::any,
        \&List::Util::first,
        \&Readonly::Readonly,
        \&Scalar::Util::weaken,
        \&Data::Dumper::Dumper,
        ]
);

use Moose::Util::TypeConstraints;

subtype 'Selector'
    => as 'Str'
    => where { $_ eq '' or /^[ST]/ }    # This restriction will be perhaps deleted.
=> message {'Selector must start with S (source) or T (target).'}
;

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

# Write just
#   use Treex::Moose;
# Instead of
#   use Moose;
#   use MooseX::SemiAffordanceAccessor;

#TODO: add
#   use List::MoreUtils qw(first_index ...);

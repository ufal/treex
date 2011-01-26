package Treex::Core;
use Moose;
use Treex::Core::Document;
#use Treex::Core::Factory;
use Treex::Core::Node;
use Treex::Core::Bundle;

use Moose::Util::TypeConstraints;

subtype 'Selector'
    => as 'Str'
    => where { $_ eq '' or /^[ST]/ } # This restriction will be perhaps deleted.
    => message {'Selector must start with S (source) or T (target).'}
;

# ISO 639-1 language code with some extensions from ISO 639-2
enum 'LangCode' => (   
    # major languages
    'en', # English
    'de', # German
    'fr', # French
    'es', # Spanish
    'it', # Italian
    'ru', # Russian
    'ar', # Arabic
    'zh', # Chinese
    # other Slavic languages
    'cs', # Czech
    'sk', # Slovak
    'pl', # Polish
    'dsb', # Lower Sorbian
    'hsb', # Upper Sorbian
    'be', # Belarusian
    'uk', # Ukrainian
    'sl', # Slovene
    'hr', # Croatian
    'sr', # Serbian
    'mk', # Macedonian
    'bg', # Bulgarian
    'cu', # Old Church Slavonic
    # other Germanic languages
    'nl', # Dutch
    'af', # Afrikaans
    'fy', # Frisian
    'lb', # Luxemburgish
    'yi', # Yiddish
    'da', # Danish
    'sv', # Swedish
    'no', # Norwegian
    'nn', # Nynorsk (New Norwegian)
    'fo', # Faroese
    'is', # Icelandic
    # other Romance and Italic languages
    'la', # Latin
    'pt', # Portuguese
    'gl', # Galician
    'ca', # Catalan
    'oc', # Occitan
    'rm', # Rhaeto-Romance
    'co', # Corsican
    'sc', # Sardinian
    'ro', # Romanian
    'mo', # Moldovan (deprecated: use Romanian)
    # Celtic languages
    'ga', # Irish
    'gd', # Scottish
    'cy', # Welsh
    'br', # Breton
    # Baltic languages
    'lt', # Lithuanian
    'lv', # Latvian
    # other Indo-European languages in Europe and Caucasus
    'sq', # Albanian
    'el', # Greek
    'hy', # Armenian
    # Iranian languages
    'fa', # Persian
    'ku-latn', # Kurdish in Latin script
    'ku-arab', # Kurdish in Arabic script
    'ku-cyrl', # Kurdish in Cyrillic script
    'os', # Ossetic
    'tg', # Tajiki (in Cyrillic script)
    'ps', # Pashto
    # Indo-Aryan languages
    'ks', # Kashmiri (in Arabic script)
    'sd', # Sindhi
    'pa', # Punjabi
    'ur', # Urdu
    'hi', # Hindi
    'gu', # Gujarati
    'mr', # Marathi
    'ne', # Nepali
    'or', # Oriya
    'bn', # Bengali
    'as', # Assamese
    'rmy', # Romany
    # other Semitic languages
    'mt', # Maltese
    'he', # Hebrew
    'am', # Amharic
    # Finno-Ugric languages
    'hu', # Hungarian
    'fi', # Finnish
    'et', # Estonian
    # other European and Caucasian languages
    'eu', # Basque
    'ka', # Georgian
    'ab', # Abkhaz
    'ce', # Chechen
    # Turkic languages
    'tr', # Turkish
    'az', # Azeri
    'cv', # Chuvash
    'ba', # Bashkir
    'tt', # Tatar
    'tk', # Turkmen
    'uz', # Uzbek
    'kaa', # Karakalpak
    'kk', # Kazakh
    'ky', # Kyrgyz
    'ug', # Uyghur
    'sah', # Yakut
    # other Altay languages
    'xal', # Kalmyk
    'bxr', # Buryat
    'mn', # Mongol
    'ko', # Korean
    'ja', # Japanese
    # Dravidian languages
    'te', # Telugu
    'kn', # Kannada
    'ml', # Malayalam
    'ta', # Tamil
    # Sino-Tibetan languages
    'zh', # Mandarin Chinese
    'hak', # Hakka
    'nan', # Taiwanese
    'yue', # Cantonese
    'lo', # Lao
    'th', # Thai
    'my', # Burmese
    'bo', # Tibetan
    # Austro-Asian languages
    'vi', # Vietnamese
    'km', # Khmer
    # other languages
    'sw', # Swahili
    'eo', # Esperanto
    'und', # ISO 639-2 code for undetermined/unknown language
);


1;

__END__

=pod

=head1 NAME

Treex::Core - velmi kratky popis treex core kvuli makemakeru


=head1 DESCRIPTION


hlavni rozcestnik k treex core


=head1 COPYRIGHT

Copyright 2010 Zdenek Zabokrtsky.....
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

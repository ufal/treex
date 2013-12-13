#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use autodie;

# Simplistic script for quick translations.
# Requires your Google Translate auth_token to be stored in your home,
# in a text file named '.gta'

sub say {
    my $line = shift;
    print "$line\n";
}

binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

{

    # I want my arguments to be UTF-8
    use I18N::Langinfo qw(langinfo CODESET);
    use Encode qw(decode);
    my $codeset = langinfo(CODESET);
    @ARGV = map { decode $codeset, $_ } @ARGV;
}

if ( @ARGV != 2 && @ARGV != 3 ) {
    die("Usage: $0 text tgt_lang [src_lang]\n" .
            "E.g.: $0 ptakopysk en cs\n"
    );
}

my ( $text, $tgt, $src ) = @ARGV;

use Treex::Tool::GoogleTranslate::APIv2;
my $translator = Treex::Tool::GoogleTranslate::APIv2->new();
my $translation = $translator->translate_simple( $text, $tgt, $src );
say $translation;


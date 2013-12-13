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
    die("Usage: $0 texts_file tgt_lang [src_lang]\n" .
            "E.g.: $0 t/texts.txt en cs\n"
    );
}

my ( $texts_file, $tgt, $src ) = @ARGV;

my $texts = [];
{
    open my $file, '<:utf8', $texts_file;
    my $line;
    while ($line = <$file>) {
        chomp $line;
        if ( $line eq '' ) {
            next;
        }
        push @$texts, $line;
    }
    close $file;
}

my $translations;
{
    use Treex::Tool::GoogleTranslate::APIv2;
    my $translator = Treex::Tool::GoogleTranslate::APIv2->new();
    $translations = $translator->translate_batch( $texts, $tgt, $src );
}

foreach my $translation (@$translations) {
    say $translation;
}



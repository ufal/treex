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

if ( @ARGV != 3 ) {
    die("Usage: $0 text src_lang tgt_lang\n" .
            "E.g.: $0 'ptakopysk obecný' cs en\n"
    );
}

my ( $text, $src, $tgt ) = @ARGV;

use Treex::Tool::GoogleTranslate::APIv1;
my $translator = Treex::Tool::GoogleTranslate::APIv1->new();
my $result = $translator->translate_align( $text, $src, $tgt );
say $result->{translation};
foreach my $align (@{$result->{align}}) {
    say $align->{word} . "\t" . $align->{position};
}


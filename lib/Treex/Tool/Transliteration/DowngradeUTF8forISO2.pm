package Treex::Tool::Transliteration::DowngradeUTF8forISO2;

# Converts UTF-8 strings to ISO-8859-2, approximating some well known
# characters. The lossy conversion is ment to help ISO-2-based tools handle
# non-ISO-2 input.
#
# Do *not* use converted strings back in TectoMT files, unless you indeed want
# to lose information.
#
# Written by Ondrej Bojar

use 5.008;
use strict;
use warnings;

use utf8;    # this file is in UTF-8

use Encode;

binmode STDERR, ":utf8";

# prepare mapping from utf-8 to iso-2, where possible
my %utf_to_8bit;
my $enc = "iso-8859-2";
for ( my $i = 128; $i < 256; $i++ ) {
    my $utf = ord( decode( $enc, chr($i) ) );
    $utf_to_8bit{$utf} = chr($i);
}

sub downgrade_utf8_for_iso2 {
    my $s                = shift;
    my $extraescapechars = shift;

    my $extraescape;
    if ( ref($extraescapechars) eq "HASH" ) {
        $extraescape = $extraescapechars;
    }
    else {
        $extraescape = { map { ( ord($_), 1 ) } split //, $extraescapechars }
            if defined $extraescapechars;
    }

    # Make text convertible to iso-8859-2
    # Heurisic approximations hopefully improving performance of following tools
    $s =~ s/[“”„«»]/"/g;
    $s =~ s/[‘’]/'/g;
    $s =~ s/[‒–—―⁓⊝⑈]/-/g;
    $s =~ s/…/.../g;
    $s =~ s{½}{1/2}g;
    $s =~ s{¼}{1/4}g;
    $s =~ s{¾}{3/4}g;

    # Now convert *all* remaining chars to &#CODE; if:
    #   - the char is beyond ISO-2
    #   - or the char is included in extraescape
    my $out = "";
    foreach my $ch ( split //, $s ) {      #/
        my $och = ord($ch);
        if ( $extraescape->{$och} ) {
            $out .= "&#" . $och . ";";
            next;
        }
        if ( $och < 128 || defined $utf_to_8bit{$och} ) {
            $out .= $ch;
        }
        else {
            $out .= "&#" . $och . ";";
        }
    }
    return $out;
}

## Micro testcases:
# print STDERR downgrade_utf8_for_iso2("AHOJ“”„.", "H");
# print STDERR downgrade_utf8_for_iso2("AHOJ“”„.", {72=>1});

1;

__END__

=pod

=head1 NAME

Treex::Tool::Transliteration::DowngradeUTF8forISO2

=head1 DESCRIPTION

Use C<downgrade_utf8_for_iso2> to convert UTF-8 string to UTF-8 string where
all non-ISO-8859-2 characters will be either approximated (e.g. quotation
marks) or converted to &#unicode; escape sequences. If you wish, you may
specify additional characters to escape, eg. '&'.

  my $reduced = downgrade_utf8_for_iso2($string, "&");

  or

  my %extraescape = map {($_,1)} qw(38);
  my $reduced = downgrade_utf8_for_iso2($string, \$extraescape);

Remember to set binmode of the output stream to ":encoding(iso-8859-2)" to
actually do the conversion.

=cut

# Copyright 2008 Ondrej Bojar

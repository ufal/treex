package Treex::Block::A2W::NormalizePunctuationForWMT;
use utf8;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $language = $zone->language;
    $_ = $zone->sentence;

    #--- start of original normalize-punctuation.perl
    s/\r//g;

    # remove extra spaces
    s/\(/ \(/g;
    s/\)/\) /g;
    s/ +/ /g;
    s/\) ([\.\!\:\?\;\,])/\)$1/g;
    s/\( /\(/g;
    s/ \)/\)/g;
    s/(\d) \%/$1\%/g;
    s/ :/:/g;
    s/ ;/;/g;

    # normalize unicode punctuation
    s/„/\"/g;
    s/“/\"/g;
    s/”/\"/g;
    s/–/-/g;
    s/—/ - /g;
    s/ +/ /g;
    s/´/\'/g;
    s/([a-z])‘([a-z])/$1\'$2/gi;
    s/([a-z])’([a-z])/$1\'$2/gi;
    s/‘/\"/g;
    s/‚/\"/g;
    s/’/\"/g;
    s/''/\"/g;
    s/´´/\"/g;
    s/…/.../g;

    # French quotes
    s/ « / \"/g;
    s/« /\"/g;
    s/«/\"/g;
    s/ » /\" /g;
    s/ »/\"/g;
    s/»/\"/g;

    # handle pseudo-spaces
    s/ \%/\%/g;
    s/nº /nº /g;
    s/ :/:/g;
    s/ ºC/ ºC/g;
    s/ cm/ cm/g;
    s/ \?/\?/g;
    s/ \!/\!/g;
    s/ ;/;/g;
    s/, /, /g;
    s/ +/ /g;

    # English "quotation," followed by comma, style
    if ( $language eq "en" ) {
        s/\"([,\.]+)/$1\"/g;
    }

    # Czech is confused
    elsif ( $language eq "cs" || $language eq "cz" ) {
    }

    # German/Spanish/French "quotation", followed by comma, style
    else {
        s/,\"/\",/g;
        s/(\.+)\"(\s*[^<])/\"$1$2/g;    # don't fix period at end of sentence
    }

    #print STDERR $_ if / ﻿/; commented out by Martin Popel

    if ( $language eq "de" || $language eq "es" || $language eq "cz" || $language eq "cs" || $language eq "fr" ) {
        s/(\d) (\d)/$1,$2/g;
    }
    else {
        s/(\d) (\d)/$1.$2/g;
    }

    #--- end of original normalize-punctuation.perl

    $zone->set_sentence($_);
    return;
}

1;

=over

=item Treex::Block::A2W::NormalizePunctuationForWMT

Simplify correct unicode punctuation to plain ASCII,
normalize spacing, ordering or quotes&comma, thousand separators etc.
Copied from http://www.statmt.org/wmt11/normalize-punctuation.perl.
The purpose of this block is BLEU comparison in WMT workshop.
NOTE: It may make the output WORSE (for humans)! 

=back

=cut

# Copyright 2011 Martin Popel based on http://www.statmt.org/wmt11/normalize-punctuation.perl
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

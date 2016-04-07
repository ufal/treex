#!/usr/bin/env perl

use strict;
use warnings;
use HTML::Entities;

binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );

while (my $line = <STDIN>){

    $line =~ s/^\s*//;
    $line =~ s/\s*\r?\n$//;
    $line =~ s/\r//g;

    # decode entities
    $line = decode_entities($line);
    $line = decode_entities($line);  # and double entities
    $line =~ s/\xA0/ /g;  # remove nbsp

    # remove control characters
    $line =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g;

    # skip empty lines
    next if ($line eq '');

    # convert paragraph marks
    $line =~ s/<br\/?>/\n/gi;
    $line =~ s/<\/?(li|ul|ol|p|h[1-7]|hr)>/\n/gi;

    # ignore character formatting
    $line =~ s/<\/?(strike|kbd|strong|em|b|i)>/\n/gi;
    
    # ignore links and images
    $line =~ s/<\/?a[^>]*>/\n/gi;
    $line =~ s/<img[^>]*>/\n/gi;

    # remove blockquotes, pre, multi-line code
    $line =~ s{<blockquote>((?:(?!</blockquote>).)*)</blockquote>}{}gsx;
    $line =~ s{<pre>((?:(?!</pre>).)*)</pre>}{}gsx;
    $line =~ s{<code>((?:(?!</code>).)*\n(?:(?!</code>).)*)</code>}{}gsx;

    # ignore inline code marks
    $line =~ s/<\/?code>/\n/gi;

    # ignore XML marks
    $line =~ s/<\?xml[^>]*>//gi;
    $line =~ s/<\/?posts[^>]*>//gi;

    # convert single newlines to spaces
    $line =~ s/\n(?!\n)/ /g;
    # remove multiple spaces
    $line =~ s/ +/ /g;
    $line =~ s/(^|\n) +/\n/g;
    $line =~ s/ +\n/\n/g;

    # convert multiple newlines to single newlines
    $line =~ s/\n(\s*\n)+/\n/g;
    
    next if $line =~ /^\s*$/;
    $line =~ s/^\s*//;
    $line =~ s/\s*\r?\n$//;
    print $line, "\n";
}

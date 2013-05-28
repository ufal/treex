#!/usr/bin/perl -w ###################################################################### 2007/06/30
#
# WhiteTXT.pl ########################################################################## Otakar Smrz

# $Id: WhiteTXT.pl 472 2008-01-21 11:56:35Z smrz $

use strict;

our $VERSION = do { q $Revision: 472 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };

use Encode::Arabic;

use XML::Twig;


our $decode = identify_encoding();

our $encode = "utf8";


our $regexQ = qr/[0-9]+(?:[\.\,\x{060C}\x{066B}\x{066C}][0-9]+)? |
                 [\x{0660}-\x{0669}]+(?:[\.\,\x{060C}\x{066B}\x{066C}][\x{0660}-\x{0669}]+)?/x;

our $regexG = qr/[\.\,\;\:\!\?\`\"\'\(\)\[\]\{\}\<\>\\\|\/\~\@\#\$\%\^\&\*\_\=\+\-\x{00AB}\x{00BB}\x{060C}\x{061B}\x{061F}]/;


our ($source, $file, $data);


# ##################################################################################################
#
# ##################################################################################################


@ARGV = glob join " ", @ARGV;


until (eof()) {

    $source = XML::Twig->new(

            'ignore_elts'   => {

                            'HEADER'    => 1,
                            'FOOTER'    => 1,

                               },

            'twig_roots'    => {

                            'HEADLINE'  => 1,
                            'hl'        => 1,

                            'DATELINE'  => 1,

                            'P'         => 1,
                            'p'         => 1,

                               },

            'twig_handlers' => {

                            'HEADLINE'  =>  \&parse_headline,
                            'hl'        =>  \&parse_headline,

                            'DATELINE'  =>  \&parse_dateline,
                            
                            'P/seg'     =>  \&parse_seg,
                            'p/seg'     =>  \&parse_seg,

                            'P'         =>  \&parse_p,
                            'p'         =>  \&parse_p,

                               },

            );

    $file = $ARGV;

    open TXT, '>', $file . '.white.txt';

    select TXT;

    $data = '';

    {
        local $/ = '</DOC>';

        $data .= <> until eof;

        $data =~ s/\n &HT;[^\n]*(?=\n &HT;|\n<\/HEADLINE>)//g;

        $data =~ s/&[A-Z][A-Za-z0-9]+;//g;

        $data =~ s/ & //g;
        
        $data =~ s/<seg id=([0-9]+)>/<seg id="$1">/g;        
    }

    $source->parse($data);

    $source->purge();

    select STDOUT;

    close TXT;
}


sub parse_headline {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('HEADLINE', $text);
}


sub parse_dateline {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('DATELINE', $text);
}


sub parse_seg {

    my ($twig, $elem) = @_;

    my $text = $elem->text();

    $twig->purge();

    process_text('TEXT', $text);
}


sub parse_p {

    my ($twig, $elem) = @_;

    warn "Problems with $file ...\n" if grep { $_->name() eq 'seg' } $elem->children();

    my $text = $elem->text();

    $twig->purge();

    process_text('TEXT', $text) unless $text =~ /^\s*$/;

}


sub process_text {

    my (undef, $data) = @_;

    $data = decode $decode, $data if defined $decode;

    while ($data =~ /(?: \G (\P{IsGraph}*) ( (?: \p{Arabic} | [\x{064B}-\x{0652}\x{0670}\x{0657}\x{0656}\x{0640}] |
                                             # \p{InArabic} |   # too general
                                            \p{InArabicPresentationFormsA} | \p{InArabicPresentationFormsB} )+ |
                                            \p{Latin}+ |
                                            $regexQ |
                                            $regexG |
                                            \p{IsGraph} ) )/gx) {

        print "" eq $1 ? " " : "\n";

        print encode $encode, $2;
    }

    print "\n\n";
}


sub identify_encoding {

    my $return = undef;

    if ($ARGV[0] eq '-E') {

        $return = $ARGV[1];

        splice @ARGV, 0, 2;
    }

    return $return;
}


__END__


=head1 NAME

WhiteTXT - White-space delimited textual data reflecting input XML/SGML documents


=head1 REVISION

    $Revision: 472 $       $Date: 2008-01-21 12:56:35 +0100 (Mon, 21 Jan 2008) $


=head1 DESCRIPTION

Prague Arabic Dependency Treebank
L<http://ufal.mff.cuni.cz/padt/online/2007/01/prague-treebanking-for-everyone-video.html>


=head1 AUTHOR

Otakar Smrz, L<http://ufal.mff.cuni.cz/~smrz/>

    eval { 'E<lt>' . ( join '.', qw 'otakar smrz' ) . "\x40" . ( join '.', qw 'seznam cz' ) . 'E<gt>' }

Perl is also designed to make the easy jobs not that easy ;)


=head1 COPYRIGHT AND LICENSE

Copyright 2004-2008 by Otakar Smrz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

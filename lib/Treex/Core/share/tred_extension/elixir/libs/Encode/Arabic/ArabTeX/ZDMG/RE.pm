# ################################################################### Otakar Smrz, 2003/01/23
#
# Encoding of Arabic: ArabTeX Notation by Klaus Lagally #####################################

# $Id: RE.pm 143 2006-11-15 01:16:57Z smrz $

package Encode::Arabic::ArabTeX::ZDMG::RE;

use 5.008;

use strict;
use warnings;

our $VERSION = do { q $Revision: 143 $ =~ /(\d+)/; sprintf "%4.2f", $1 / 100 };


sub import {            # perform import as if Encode were used one level before this module
    require Encode;
    Encode->export_to_level(1, @_);
}


use Encode::Encoding;
use base 'Encode::Encoding';

__PACKAGE__->Define('ZDMG-RE', 'ArabTeX-ZDMG-RE');


our (%encode_used, %decode_used, @shams, @qamar);


sub encode ($$;$$) {
    my (undef, $text, $check, $mode) = @_;

    $_[1] = '' if $check;                   # this is what in-place edit needs

    require Encode;

    Encode::_utf8_off($text);

    return $text;
}


sub decode ($$;$) {
    my (undef, $text, $check) = @_;

    $_[1] = '' if $check;                   # this is what in-place edit needs

    for ($text) {

        s/NY/n/g;
        s/UA/u\x{0304}/g;
        s/WA/w/g;
        s/_a/a\x{0304}/g;

        s/N/n/g;
        s/Y/a\x{0304}/g;
        s/T/t/g;

        #s/y/j/g;

        s/\\cap\s+([\._\^]?)([a-zAIU])/$1\*$2/g;
        s/\\cap\s+(['`])([a-zAIUEO])/\*$1\*$2/g;

        s/\.(\*?[hsdtz])/$1\x{0323}/g;
        s/\.(\*?g)/$1\x{0307}/g;

        s/_(\*?[td])/$1\x{0331}/g;
        s/_(\*?)h/$1\x{032E}/g;

        #s/_(\*?)h/$1ch/g;

        s/\^(\*?[gs])/$1\x{030C}/g;

        #s/\^(\*?s)/\\v{$1}/g;
        #s/\^(\*?)g/$1d\\v{z}/g;

        s/(?<!\*)([AUEO])/\l$1\x{0304}/g;
        s/(?<!\*)I/\x{0131}\x{0304}/g;
        s/\*([AIUEO])/$1\x{0304}/g;

        s/\*?'/\x{02BE}/g;
        s/\*?`/\x{02BF}/g;

        s/\*([a-z])/\u$1/g;
    }

    return $text;
}


1;

__END__


=head1 NAME

Encode::Arabic::ArabTeX::ZDMG::RE - Deprecated Encode::Arabic::ArabTeX::ZDMG implemented with regular expressions


=head1 REVISION

    $Revision: 143 $        $Date: 2006-11-15 04:16:57 +0300 (Wed, 15 Nov 2006) $


=head1 SYNOPSIS

    use Encode::Arabic::ArabTeX::ZDMG::RE;

    $string = decode 'arabtex-zdmg-re', $octets;
    $octets = encode 'arabtex-zdmg-re', $string;    # not implemented, returns _utf8_off($string)


=head1 DESCRIPTION

Deprecated method using sequential regular-expression substitutions. Limited in scope over the ArabTeX notation
and non-efficient in data processing, still, not requiring the L<Encode::Mapper|Encode::Mapper> module.

Originally, the method helped data typesetting in TeX. It has been modified to produce correct Perl's
representation engaging Combining Diacritical Marks from the Unicode Standard, Version 4.0.


=head2 EXPORT

Exports as if C<use Encode> also appeared in the package.


=head1 SEE ALSO

L<Encode::Arabic::ArabTeX::ZDMG|Encode::Arabic::ArabTeX::ZDMG>


=head1 AUTHOR

Otakar Smrz, L<http://ufal.mff.cuni.cz/~smrz/>

    eval { 'E<lt>' . ( join '.', qw 'otakar smrz' ) . "\x40" . ( join '.', qw 'seznam cz' ) . 'E<gt>' }

Perl is also designed to make the easy jobs not that easy ;)


=head1 COPYRIGHT AND LICENSE

Copyright 2003-2006 by Otakar Smrz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

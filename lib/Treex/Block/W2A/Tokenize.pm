package Treex::Block::W2A::Tokenize;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TokenizeOnWhitespace';

# On some inputs we get "Malformed utf8 character" warnings, but only with Perl 5.12, not with 5.14.
# Let's suppress all utf8 warnings. TODO: find the real cause.
no warnings 'utf8';

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;

    # first off, add a space to the beginning and end of each line, to reduce necessary number of regexps.
    $sentence =~ s/$/ /;
    $sentence =~ s/^/ /;

    # The following characters (double-characters) are separated everywhere and cannot be used inside URLs.
    # It is quite common than an URL is enclosed in quotes
    # and URI::Find::Schemeless does not recognize such URLs, so we need to separate it first.
    $sentence =~ s/(["<>{}“”«»–|—„‚‘]|\[|\]|``|\'\'|‘‘|\^)/ $1 /g;

    # detect web sites and email addresses and protect them from tokenization
    $sentence = $self->_mark_urls($sentence);

    # the following characters (double-characters) are separated everywhere (except inside URLs)
    $sentence =~ s/([;!()?#\$£%&*]|--)/ $1 /g;

    # short hyphen is separated if it is followed or preceeded by non-alphanuneric character and is not a part of --, or a unary minus
    $sentence =~ s/([^\-\w])\-([^\-0-9])/$1 - $2/g;
    $sentence =~ s/([0-9]\s+)\-([0-9])/$1 - $2/g; # preceded by a number - not a unary minus
    $sentence =~ s/([^\-])\-([^\-\w])/$1 - $2/g;

    # plus is separated everywhere, except at the end of a word (separated by a space) and as unary plus
    $sentence =~ s/(\w)\+(\w)/$1 + $2/g;
    $sentence =~ s/([0-9]\s*)\+([0-9])/$1 + $2/g;
    $sentence =~ s/\+([^\w\+])/+ $1/g;

    # apostroph is separated if it is followed or preceeded by non-alphanumeric character, is not part of '', and is not followed by a digit (e.g. '60).
    $sentence =~ s/([^\'’\w])([\'’])([^\'’\d])/$1 $2 $3/g;
    $sentence =~ s/([^\'’])([\'’])([^\'’\w])/$1 $2 $3/g;

    # dot, comma, slash, and colon are separated if they do not connect two numbers
    $sentence =~ s/(\D|^)([\.,:\/])/$1 $2 /g;
    $sentence =~ s/([\.,:\/])(\D|$)/ $1 $2/g;

    # three dots belong together
    $sentence =~ s/\.\s*\.\s*\./.../g;

    # get back web sites and e-mails
    $sentence = $self->_restore_urls($sentence);

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^ *//g;
    $sentence =~ s/ *$//g;

    return $sentence;
};

use URI::Find::Schemeless;
my @urls;
my $finder = URI::Find::Schemeless->new(sub {
    my ($uri, $orig_uri) = @_;
    push @urls, $orig_uri;
    return 'XXXURLXXX';
});

# internally marks URLs, so they won't be splitted
sub _mark_urls {
    my ( $self, $sentence ) = @_;
    @urls = ();
    # URI::Find::Schemeless cannot detect URLs which are not preceded by a space (or beggining of string).
    # Various types of brackets were already separated, but it is possible to find e.g. "go to:http://mysite.com"
    # without the space after colon (or comma, or other word). Let's detect such URLs as well.
    $sentence =~ s|(?<!\s)(https?://|www\.)| $1|g;
    $finder->find(\$sentence);
    return $sentence;
}

# pushes bask URLs, marked by C<_mark_urls>
sub _restore_urls {
    my ( $self, $sentence ) = @_;
    while (@urls) {
        my $url = shift @urls;
        $sentence =~ s/XXXURLXXX/$url/;
    }
    return $sentence;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::Tokenize - language independent rule based tokenizer

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens using a series of regexs.
Flat a-tree is built and attributes C<no_space_after> are filled.
This class uses language-independent regex rules for tokenization,
but it can be used as an ancestor for language-specific tokenization
by overriding the method C<tokenize_sentence>
or by using C<around> (see L<Moose::Manual::MethodModifiers>).

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


package Treex::Block::W2A::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TokenizeOnWhitespace';

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;

    # first off, add a space to the beginning and end of each line, to reduce necessary number of regexps.
    $sentence =~ s/$/ /;
    $sentence =~ s/^/ /;

    # detect web sites and email addresses and protect them from tokenization
    $sentence = $self->mark_urls($sentence);

    # the following characters (double-characters) are separated everywhere
    $sentence =~ s/(;|!|<|>|\{|\}|\[|\]|\(|\)|\?|\#|\$|£|\%|\&|``|\'\'|‘‘|"|“|”|«|»|--|—|„|‚|\*|\^)/ $1 /g;

    # short hyphen is separated if it is followed or preceeded by non-alphanuneric character and is not a part of --
    $sentence =~ s/([^\-\w])\-([^\-])/$1 - $2/g;
    $sentence =~ s/([^\-])\-([^\-\w])/$1 - $2/g;

    # apostroph is separated if it is followed or preceeded by non-alphanumeric character, is not part of '', and is not followed by a digit (e.g. '60).
    $sentence =~ s/([^\'’\w])([\'’])([^\'’\d])/$1 $2 $3/g;
    $sentence =~ s/([^\'’])([\'’])([^\'’\w])/$1 $2 $3/g;

    # dot, comma, slash, and colon are separated if they do not connect two numbers
    $sentence =~ s/(\D|^)([\.,:\/])/$1 $2 /g;
    $sentence =~ s/([\.,:\/])(\D|$)/ $1 $2/g;

    # three dots belong together
    $sentence =~ s/\.\s*\.\s*\./.../g;

    # get back web sites and e-mails
    $sentence = $self->restore_urls($sentence);

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^ *//g;
    $sentence =~ s/ *$//g;

    return $sentence;
};

has _urls => ( is => 'rw' );

sub mark_urls {
    my ( $self, $sentence ) = @_;
    my @urls;
    while ( $sentence =~ s/(\W)((http:\/\/)?([\w\-]+\.)+(com|cz|de|es|eu|fr|hu|it|sk))(\W)/$1 XXXURLXXX $6/ ) {
        push @urls, $2;
    }
    $self->_set_urls( \@urls );
    return $sentence;
}

sub restore_urls {
    my ( $self, $sentence ) = @_;
    my @urls = @{ $self->_urls };
    while (@urls) {
        my $url = shift @urls;
        $sentence =~ s/XXXURLXXX/$url/;
    }
    return $sentence;
}

1;

__END__

TODO POD

=over

=item Treex::Block::W2A::Tokenize

Each sentence is split into a sequence of tokens using a series of regexs.
Flat a-tree is built and attributes C<no_space_after> are filled.
This class uses language-independent regex rules for tokenization,
but it can be used as an ancestor for language-specific tokenization
by overriding the method C<tokenize_sentence>
or by using C<around> (see L<Moose::Manual::MethodModifiers>).

=back

=cut

# Copyright 2010-2011 David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::W2A::CS::Tokenize;
use utf8;
use Moose;
use Treex::Moose;

extends 'Treex::Block::W2A::Tokenize';

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence =~ s/[^\s[alnum:]]/ $1 /g;

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^\s*//g;
    $sentence =~ s/\s*$//g;

    return $sentence;
};

1;

__END__

=over

=item Treex::Block::W2A::CS::Tokenize

Each sentence is split into a sequence of token. Non-alphanumeric
characters become single tokens.

=back

=cut

# Copyright 2011 David Marece
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

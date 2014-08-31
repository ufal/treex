package Treex::Block::W2A::CS::Tokenize;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

override 'tokenize_sentence' => sub {

    my ( $self, $sentence ) = @_;

    $sentence = super();

    # pad with spaces for easier regexps
    $sentence =~ s/^(.*)$/ $1 /;

    # Czech conditional enclitic "-li" should be treated as a separate token
    $sentence =~ s/ (\p{Letter}+)-(li|LI) / $1 - $2 /g;
    
    # Number ranges are considered 3 tokens in PDT (and thus learned to be treated so by parsers)
    $sentence =~ s/([0-9])\-([0-9])/$1 - $2/g;

    # clean out extra spaces
    $sentence =~ s/^\s*//g;
    $sentence =~ s/\s*$//g;

    return $sentence;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::CS::Tokenize

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens. The L<default language-independent tokenization|Treex::Block::W2A::Tokenize> 
is used.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

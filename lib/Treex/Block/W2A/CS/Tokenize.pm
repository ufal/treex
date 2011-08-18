package Treex::Block::W2A::CS::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

override 'tokenize_sentence' => sub {

    my ( $self, $sentence ) = @_;

    $sentence = super();

    # pad with spaces for easier regexps
    $sentence =~ s/^(.*)$/ $1 /;

    # possibly add some work here

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

package Treex::Block::W2A::EN::Tokenize;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
    $sentence =~ s/^(.*)$/ $1 /;

    # it's, I'm, we'd, we're, you'll, I've, Peter's
    $sentence =~ s/([\'’´])(s|m|d|ll|re|ve|S|M|D|LL|RE|VE)\s/ $1$2 /g;

    # don't
    $sentence =~ s/(n[\'’´]t\s)/ $1 /g;
    $sentence =~ s/(N[\'’´]T\s)/ $1 /g;

    # cannot, wanna ...
    $sentence =~ s/ ([Cc])annot / $1an not /g;
    $sentence =~ s/ ([Dd])'ye / $1' ye /g;
    $sentence =~ s/ ([Gg])imme / $1im me /g;
    $sentence =~ s/ ([Gg])onna / $1on na /g;
    $sentence =~ s/ ([Gg])otta / $1ot ta /g;
    $sentence =~ s/ ([Ll])emme / $1em me /g;
    $sentence =~ s/ ([Mm])ore'n / $1ore 'n /g;
    $sentence =~ s/ '([Tt])is / '$1 is /g;
    $sentence =~ s/ '([Tt])was / '$1 was /g;
    $sentence =~ s/ ([Ww])anna / $1an na /g;

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^\s*//g;
    $sentence =~ s/\s*$//g;

    return $sentence;
};

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::EN::Tokenize - rule-based tokenization

=head1 DESCRIPTION

Each sentence is split into a sequence of tokens using a series of regexs.
Flat a-tree is built and attributes C<no_space_after> are filled.
This class uses English specific regex rules (insipred by PennTB) for tokenization
of contractions like I<He's, we'll, they've, don't> etc.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

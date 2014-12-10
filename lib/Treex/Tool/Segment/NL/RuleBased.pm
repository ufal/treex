package Treex::Tool::Segment::NL::RuleBased;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Segment::RuleBased';

# Note that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{
    \p{Upper}            # single uppercase letters

    # period-ending items that never indicate sentence breaks
    |a\.g\.v|bijv|bijz|bv|d\.w\.z|e\.c|e\.g|e\.k|ev
    |i\.p\.v|i\.s\.m|i\.t\.t|i\.v\.m
    |m\.a\.w|m\.b\.t|m\.b\.v|m\.h\.o|m\.i|m\.i\.v|v\.w\.t

    # titles before names of persons, etc.
    |bacc|bc|bgen|c\.i|dhr|[Dd]r|[Dd]r\.h\.c|Drs|drs|ds
    |eint|[Ff]a|fam|gen|genm|[Ii]ng|ir|jhr|jkvr|jr
    |kand|kol|lgen|lkol|Lt|maj|Mej|[Mm]evr|Mme|[Mm]r
    |Mw|o\.b\.s|plv|[Pp]rof|ritm|tint|Vz|Z\.D|Z\.D\.H
    |Z\.E|Z\.Em|Z\.H|Z\.K\.H|Z\.K\.M|Z\.M|z\.v
}x;    ## no critic (RegularExpressions::ProhibitComplexRegexes) this is nothing complex, just list

override unbreakers => sub {
    return $UNBREAKERS;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Segment::NL::RuleBased - rule based sentence segmenter for Dutch

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.

This class adds a Dutch specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

The list itself is taken from Moses's "nonbreaking_prefixes".

See L<Treex::Block::W2A::Segment>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Tool::Segment::ES::RuleBased;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Segment::RuleBased';

# Note, that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{
    \p{Upper}            # single uppercase letters
    |v|vs|i\.e|rev|e\.g  # period-ending items that never indicate sentence breaks
    |I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX
    |i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xiii|xiv|xv|xvi|xvii|xviii|xix|xx
    |A\.C|Apdo|Av|Bco|CC\.AA|Da|Dep|Dn|Dr|Dra|EE\.UU|Excmo|FF\.CC|Fil|Gral|J\.C
    |Let|Lic|N\.B|P\.D|P\.V\.P|Prof|Pts|Rte|S\.A|S\.A\.R|S\.E|S\.L|S\.R\.C|vol
    |Sr|Sra|Srta|Sta|Sto|T\.V\.E|Tel|Ud|Uds|V\.B|V\.E|Vd|Vds|a\/c|adj|admón|afmo
    |apdo|av|c|c\.f|c\.g|cap|cm|cta|dcha|doc|ej|entlo|esq|etc|f\.c|gr|grs|izq|kg
    |km|mg|mm|núm|p|p\.a|p\.ej|ptas|pág|págs|q\.e\.g\.e|q\.e\.s\.m|s|s\.s\.s|vid
}x;    ## no critic (RegularExpressions::ProhibitComplexRegexes) this is nothing complex, just list

override unbreakers => sub {
    return $UNBREAKERS;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Segment::ES::RuleBased - rule based sentence segmenter for Spanish

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a Spanish specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

See L<Treex::Block::W2A::Segment>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Tool::Segment::PT::RuleBased;

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
    |Adj|Adm|Adv|Art|Ca|Capt|Cmdr|Col|Comdr|Con|Corp|Cpl|DR|DRA|Dr|Dra|Dras|Drs
    |Eng|Enga|Engas|Engos|Ex|Exo|Exmo|Fig|Gen|Hosp|Insp|Lda|MM|MR|MRS|MS|Maj
    |Mrs|Ms|Msgr|Op|Ord|Pfc|Ph|Prof|Pvt|Rep|Reps|Res|Rev|Rt|Sen|Sens|Sfc|Sgt
    |Sr|Sra|Sras|Srs|Sto|Supt|Surg|adj|adm|adv|art|cit|col|con|corp|cpl|dr|dra
    |dras|drs|eng|enga|engas|engos|ex|exo|exmo|fig|op|prof|sr|sra|sras|srs|sto
}x;    ## no critic (RegularExpressions::ProhibitComplexRegexes) this is nothing complex, just list

override unbreakers => sub {
    return $UNBREAKERS;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Segment::PT::RuleBased - rule based sentence segmenter for Portuguese

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a portuguese specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

See L<Treex::Block::W2A::Segment>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

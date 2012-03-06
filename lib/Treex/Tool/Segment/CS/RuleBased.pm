package Treex::Tool::Segment::CS::RuleBased;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Segment::RuleBased';

# Note, that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{\p{Upper}|Fr|Vl|    # first name
    pí?|                                # "pan", "paní"
    ing|arch|                           # academic titles
    (ph|rn|paed?|ju|mu|mv|md|rs)dr|
    prof|doc|mgr|bc|
    sv|                                 # "svatý"
    gen|p?plk|[np]?por|š?kpt|mjr|       # military titles
    např|srov|tzv|mj                    # listing
}xi;

override unbreakers => sub {
    return $UNBREAKERS;
};

# Characters that can appear after period (or other end-sentence symbol)
sub closings {
    return '"”“»)';
}

# Characters that can appear before the first word of a sentence
sub openings {
    return '"“„«(';
}



1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Segment::CS::RuleBased

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a Czech specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

=head1 TODO

Errors seen on PDT 2.0 d-test set:

Segmenting too much:

ordinal numbers (needed badly!), tis./mil./mld. Kč/USD, a.s. <address/company name>,  hl. m. Praha, 
v. (versus), kap. <chapter name>, vš. SKP Plzeň (?)

Not segmenting:

captions (unsolvable?), asterisk at sentence beginning (interviews)

=head1 SEE ALSO

L<Treex::Block::W2A::Segment>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

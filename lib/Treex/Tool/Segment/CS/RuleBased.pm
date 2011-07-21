package Treex::Tool::Segment::CS::RuleBased;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Segment::RuleBased';

# Note, that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{ing|dr|mgr|bc|gen|sv}xi;

override unbreakers => sub {
    return $UNBREAKERS;
};

1;

__END__

=over

=item Treex::Tool::Segment::CS::RuleBased

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a Czech specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

See L<Treex::Block::W2A::Segment>

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

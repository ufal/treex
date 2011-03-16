package Treex::Tools::Segment::EN::RuleBased;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Tools::Segment::RuleBased';

# Note, that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{
    \p{Upper}            # single uppercase letters (with a rare exception of I)
    |v|vs|i\.e|rev|e\.g  # period-ending items that never indicate sentence breaks
    |Adj|Adm|Adv|Asst    # titles before names of persons, etc.
    |Bart|Bldg|Brig|Bros|Capt|Cmdr|Col|Comdr|Con|Corp|Cpl|DR|Dr|Drs|Ens|Gen|Gov
    |Hon|Hr|Hosp|Insp|Lt|MM|MR|MRS|MS|Maj|Messrs|Mlle|Mme|Mr|Mrs|Ms|Msgr|Op|Ord
    |Pfc|Ph|Prof|Pvt|Rep|Reps|Res|Rev|Rt|Sen|Sens|Sfc|Sgt|Sr|St|Supt|Surg
}x;

override unbreakers => sub {
    return $UNBREAKERS;
};

1;

__END__

=over

=item Treex::Tools::Segment::EN::RuleBased

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a English specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

See L<Treex::Block::W2A::Segment>

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

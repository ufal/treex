package Treex::Block::HamleDT::Test::UD::AuxpassImpliesSubjpass;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my @children = $node->children();
    my @auxpass = grep {$_->deprel() =~ m/^auxpass/} (@children);
    if(scalar(@auxpass) > 0)
    {
        my @subj = grep {$_->deprel() =~ m/^[nc]subj$/} (@children);
        foreach my $subj (@subj)
        {
            $self->complain($node, 'Non-passive subject cannot co-occur with a passive auxiliary.');
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::AuxpassImpliesSubjpass

If a predicate has an C<auxpass> (or C<auxpass:refl>) child, its subject must
be C<nsubjpass> or C<csubjpass> but not C<nsubj> or C<csubj>. Note that the
other implication does not hold because there may be several auxiliaries and
some of them may not be responsible for the passive voice. Also note that both
the subject and the auxiliary may be omitted.

=back

=cut

# Copyright 2016 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

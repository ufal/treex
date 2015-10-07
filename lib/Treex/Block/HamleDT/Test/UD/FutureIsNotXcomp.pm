package Treex::Block::HamleDT::Test::UD::FutureIsNotXcomp;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $deprel = $node->deprel();
    $deprel = '' if(!defined($deprel));
    if($deprel eq 'xcomp')
    {
        # Note that there are other cases than infinitives where we use xcomp (Czech doplněk).
        # Here we are only interested in infinitives.
        if($node->is_infinitive())
        {
            # Are there any future auxiliary children?
            my @children = $node->children();
            if(any {$_->deprel() eq 'aux' && $_->iset()->tense() eq 'fut'} (@children))
            {
                $self->complain($node, 'Future + infinitive should not be labeled xcomp');
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::FutureIsNotXcomp

Infinitives attached as complements to other verbs are usually labeled C<xcomp>
because their subject is controlled by the parent verb.

However, in some languages there are periphrastic forms of future tense that
consist of the infinitive of the main verb and a finite form of an auxiliary
verb. Subjects of these verb groups are not controlled because the combination
verb+auxiliary as a whole is finite. If it happens to complement another verb,
it must be labeled C<ccomp> and not C<xcomp>.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

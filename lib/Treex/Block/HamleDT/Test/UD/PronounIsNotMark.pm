package Treex::Block::HamleDT::Test::UD::PronounIsNotMark;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $deprel = $node->deprel() // '';
    if($deprel eq 'mark')
    {
        if($node->is_pronoun())
        {
            $self->complain($node, 'Pronoun should not be labeled mark');
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::PronounIsNotMark

Some treebanks confuse relative pronouns with subordinating conjunctions.
Subordinating conjunctions are attached as C<mark> but this relation should
never be used for pronouns because they play a role (even if only optional)
in the valency frame of the subordinate predicate.

=back

=cut

# Copyright 2016 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

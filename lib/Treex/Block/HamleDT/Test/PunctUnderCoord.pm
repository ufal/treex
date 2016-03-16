package Treex::Block::HamleDT::Test::PunctUnderCoord;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if(($node->deprel() || '') eq 'Coord')
    {
        my $leftmost = $node->get_descendants({first_only=>1});
        my $rightmost = $node->get_descendants({last_only=>1});
        if(defined($leftmost) && defined($rightmost))
        {
            my $lord = $leftmost->ord();
            my $rord = $rightmost->ord();
            # Find all punctuation symbols that conflict with the coordination.
            my (@punct) = grep {$_->ord() > $lord && $_->ord() < $rord && $_->form() =~ m/^[[:punct:]]+$/} $node->get_siblings();
            if(scalar(@punct) > 0)
            {
                $self->complain($node);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::PunctUnderCoord

Punctuation should not appear as a sibling of a coordination if it is between the leftmost and the rightmost children of that coordination.

=back

=cut

# Copyright 2012 Jindra Helcl
# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::HamleDT::Test::PunctUnderCoord;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if (($anode->afun || '') eq 'Coord') {

	my $leftmost = $anode->get_descendants({first_only=>1});
	my $rightmost = $anode->get_descendants({last_only=>1});

	# take all punctuations that conflicts with the coordination and rehang them to the coord node
	my (@puncts) = grep {$_->ord > $leftmost->ord && $_->ord < $rightmost->ord && $_->form =~ m/^[[:punct:]]+$/} $anode->get_siblings;

	if( scalar @puncts > 0) {
	    $self->complain($anode);
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
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


package Treex::Block::Test::A::PunctUnderRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if (!(($anode->afun eq 'AuxK') && ($anode->get_parent->afun eq 'AuxS'))) { # end punctiation must be directly under root

	my $leftmost = $anode->get_descendants({first_only=>1});
	my $rightmost = $anode->get_descendants({last_only=>1});

    if (!($leftmost->afun eq 'AuxG') && ($rightmost->afun eq 'AuxG')) { # if not can be direct speak 
	    $self->complain($anode);
	}
    }
}

1;

=over

=item Treex::Block::Test::A::PunctUnderRoot

AuxK should be direct under root one exception is direct speak

=back

=cut

# Copyright 2012 Jindra Helcl
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


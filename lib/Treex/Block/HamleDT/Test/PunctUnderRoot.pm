package Treex::Block::Test::A::PunctUnderRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    return unless $anode->afun eq 'AuxK';

    my $parent = $anode->get_parent;

    if ($parent->afun ne 'AuxS') {

	my $left = $parent->get_children({first_only=>1});
	my $right = $parent->get_children({last_only=>1});

    unless ($left->afun eq 'AuxG' || $right->afun eq 'AuxG') { 
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


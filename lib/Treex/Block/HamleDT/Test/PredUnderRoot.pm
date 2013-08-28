package Treex::Block::HamleDT::Test::PredUnderRoot;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if (($anode->afun || '') eq 'Pred') {
        foreach my $parent ($anode->get_eparents({ dive => 'AuxCP' })) {
            if ($parent->afun ne 'AuxS' && !$anode->is_member && !$anode->is_parenthesis_root) {
                $self->complain($anode, $parent->afun);
            }
        }
    }

}

1;

=over

=item Treex::Block::HamleDT::Test::PredUnderRoot

Each predicate must be directly (effectively) dependant on the root node.

=back

=cut

# Copyright 2011 Honza Vacl
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


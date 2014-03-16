package Treex::Block::HamleDT::Test::AtvVBelowVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if (($anode->afun||'') eq 'AtvV') { # Atrv must be under Verb
        foreach my $parent ($anode->get_eparents()) {
            if ($parent->get_attr('iset/pos') eq 'verb' ) {
                $self->complain($anode);
            }
        }
    }
    return;
}

1;

=over

=item Treex::Block::HamleDT::Test::AtvVBelow;

AtvV must be below verb
=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


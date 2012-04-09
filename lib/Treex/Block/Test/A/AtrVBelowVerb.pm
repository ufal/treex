package Treex::Block::Test::A::AtrVBelow;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
      if (($anode->afun||'') eq 'AtrV') { # Atrv must be under Verb
        foreach my $parent ($anode->get_eparents()) {
            if ($parent->get_attr('iset/pos') eq 'verb' ) {

#                if ($parent->afun() ne 'AuxC') { # modern greek 
                    $self->complain($anode);
#                }
            }
        }
    }
    return;
}

}

1;

=over

=item Treex::Block::Test::A::AtrVBelow;

AtrV must be below verb
=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


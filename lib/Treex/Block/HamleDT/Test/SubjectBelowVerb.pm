package Treex::Block::HamleDT::Test::SubjectBelowVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if (($anode->afun||'') eq 'Sb') {
        foreach my $parent ($anode->get_eparents({ dive => 'AuxCP' })) {
            if (defined $parent->get_attr('iset/pos')
                    and $parent->get_attr('iset/pos') ne 'verb' ) {

#                if ($parent->afun() ne 'AuxC') { # modern greek 
                    $self->complain($anode);
#                }
            }
            else {
                $self->praise($anode);
            }
        }
    }
    return;
}

1;

=over

=item Treex::Block::HamleDT::Test::SubjectBelowVerb

Subjects (afun=Sb) are expected only below verbs.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.


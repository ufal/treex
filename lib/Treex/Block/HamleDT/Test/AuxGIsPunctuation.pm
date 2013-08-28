package Treex::Block::Test::A::AuxGIsPunctuation;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;
    if ( ($anode->afun eq "AuxG")
             &&  ($anode->tag !~ /^Z:/) ) {
        $self->complain($anode, $anode->afun." : ".$anode->tag);
    }
}

1;

=over

=item Treex::Block::Test::A::AuxGIsPunctuation

A node with afun AuxG should be a punctuation (based on tag).

=back

=cut

# Copyright 2012 Honza Vacl
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

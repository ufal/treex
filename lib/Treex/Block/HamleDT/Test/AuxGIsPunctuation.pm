package Treex::Block::HamleDT::Test::AuxGIsPunctuation;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() eq 'AuxG' && !$node->is_punctuation())
    {
        $self->complain($node, 'AuxG : '.$node->tag());
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::AuxGIsPunctuation

A node attached as AuxG must be POS-tagged as punctuation.

=back

=cut

# Copyright 2012 Honza Václ
# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

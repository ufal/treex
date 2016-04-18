package Treex::Block::HamleDT::Test::SubjectUnderVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if(($node->deprel() || '') eq 'Sb')
    {
        # The direct parent node could be Coord, Apos, AuxP or AuxC. In all these cases the real parent (verb) is elsewhere.
        # We should call $node->get_eparents({'dive' => 'AuxCP'}) but it works with afuns and we do not have afuns, we have deprels.
        # Therefore we will just ignore these parents for the time being.
        my $parent = $node->parent();
        if($parent->deprel() !~ m/^(Coord|Apos|Aux[PC])/ && !$parent->is_verb())
        {
            $self->complain($node);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::SubjectUnderVerb

Subjects (deprel=Sb) are expected only under verbs.

=back

=cut

# Copyright 2011 Zdeněk Žabokrtský
# Copyright 2015, 2016 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

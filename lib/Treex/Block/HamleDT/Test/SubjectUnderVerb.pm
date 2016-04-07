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
        my @eparents = $node->get_eparents({'dive' => 'AuxCP'});
        foreach my $parent (@eparents)
        {
            if(!$parent->is_verb())
            {
                $self->complain($node);
            }
            else
            {
                $self->praise($node);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::SubjectUnderVerb

Subjects (afun=Sb) are expected only under verbs.

=back

=cut

# Copyright 2011 Zdeněk Žabokrtský
# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

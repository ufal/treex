package Treex::Block::HamleDT::Test::UD::Reflexives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # compound:reflex should only be used with reflexive pronouns.
        # Unfortunately the conversion to Prague merged AuxT with verbal particles and other compounds.
        # This block checks whether we succeeded in separating them again.
        if($node->deprel() eq 'compound:reflex' && !$node->is_reflexive())
        {
            $self->complain($node, $node->form().' '.$deprel);
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::Reflexives

The relation C<compound:reflex> should only be used with reflexive pronouns.
Unfortunately the conversion to the Prague style merged C<AuxT> with verbal
particles and other compounds. This block checks whether we succeeded in
separating them again.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::Eval::ListNonProjTrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

my $n_nodes;
my %n_nonproj;

#------------------------------------------------------------------------------
# Prints address of a-tree if it contains a nonprojective dependency.
#------------------------------------------------------------------------------
sub process_zone
{
	my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
	my @nodes = $root->get_descendants( { 'add_self' => 1, 'ordered' => 1 } );
    foreach my $node (@nodes)
    {
        if($node->is_nonprojective())
        {
            # print the address of the non-projective tree
            print $node->get_address() . "\n";
            # no need to examine the same tree further
            last;
        }
	}
}

1;

=over

=item Treex::Block::Eval::ListNonProjTrees

Lists non-projective trees from treex files. The list can be written into
file (ex: nonprojtrees.lst) & can be viewed using the following command,

shell$ ttred -l nonprojtrees.lst

or

shell$ treex -s Eval::ListNonProjTrees -- *.treex.gz | ttred -l -

In fact, the list of positions refers directly to nonprojective nodes, not tree roots.
However, for each nonprojective tree only the first nonprojective node will be reported.

=back

=cut

# Copyright 2011 Daniel Zeman
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

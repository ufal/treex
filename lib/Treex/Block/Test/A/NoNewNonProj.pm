package Treex::Block::Test::A::NoNewNonProj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

#------------------------------------------------------------------------------
# Iterates over nodes of the old and the new tree in parallel.
#------------------------------------------------------------------------------
sub process_bundle
{
    my $self = shift;
    my $bundle = shift;
    # Look for languages where there is a pair of the old and the new zone.
    my @zones = $bundle->get_all_zones();
    my %zones;
    foreach my $zone (@zones)
    {
        my $language = $zone->language();
        my $selector = $zone->selector() // '';
        $zones{$language}{$selector} = $zone;
    }
    foreach my $zone (@zones)
    {
        my $language = $zone->language();
        my $selector = $zone->selector() // '';
        if($selector eq 'orig' && exists($zones{$language}{''}))
        {
            # We found a pair of zones before and after the HamleDT harmonization.
            # Let's check that the new zone does not introduce new nonprojectivities.
            my $old_zone = $zone;
            my $new_zone = $zones{$language}{''};
            my $old_tree = $old_zone->get_atree();
            my $new_tree = $new_zone->get_atree();
            my @old_nodes = $old_tree->get_descendants({'ordered' => 1});
            my @new_nodes = $new_tree->get_descendants({'ordered' => 1});
            my $oldn = scalar(@old_nodes);
            my $newn = scalar(@new_nodes);
            log_warning("The new tree does not have the same number of nodes as the old one.") if($newn!=$oldn);
            my $n = $oldn<=$newn ? $oldn : $newn;
            for(my $i = 0; $i<$n; $i++)
            {
                if(!$old_nodes[$i]->is_nonprojective() && $new_nodes[$i]->is_nonprojective())
                {
                    $self->complain($new_nodes[$i]);
                }
            }
        }
    }
}

1;

=over

=item Treex::Block::Test::A::NoNewNonProj

Harmonization of treebank annotation towards the HamleDT annotation scheme should not introduce new non-projectivities.
This block compares two zones of one language, "orig" and "".
For nodes that were not non-projective in the original zone, checks that they remain projective in the new zone.

=back

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

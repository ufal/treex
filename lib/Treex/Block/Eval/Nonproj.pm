package Treex::Block::Eval::Nonproj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

my $n_nodes;
my %n_nonproj;



#------------------------------------------------------------------------------
# Counts nonprojective dependencies in the a-tree of a zone.
#------------------------------------------------------------------------------
sub process_bundle
{
    my $self = shift;
    my $bundle = shift;
    my @zones = $bundle->get_all_zones();
    foreach my $zone (@zones)
    {
        my $label = $zone->get_label();
        # Make sure that all zones appear in the report even if they are projective.
        if(!exists($n_nonproj{$label}))
        {
            $n_nonproj{$label} = 0;
        }
        my $count_nodes = $label eq $self->language();
        my $root = $zone->get_atree();
        my @nodes = $root->get_descendants({'add_self' => 1, 'ordered' => 1});
        my $n = $#nodes;
        foreach my $node (@nodes)
        {
            next if($node==$root);
            if($count_nodes)
            {
                $n_nodes++;
            }
            # Is this node attached nonprojectively?
            if($node->is_nonprojective())
            {
                $n_nonproj{$label}++;
            }
        }
    }
}



#------------------------------------------------------------------------------
# Prints out statistics.
#------------------------------------------------------------------------------
sub process_end
{
    my $self = shift;
    my @zones = sort(keys(%n_nonproj));
    if(@zones)
    {
        foreach my $zone (sort(keys(%n_nonproj)))
        {
            my $ratio = $n_nodes ? $n_nonproj{$zone}/$n_nodes : 0;
            print("$zone\t$n_nonproj{$zone}/$n_nodes\t$ratio\n");
        }
    }
    else
    {
        print("No zone visited, no nonprojectivity found.\n");
    }
}



1;

=over

=item Treex::Block::Eval::Nonproj

Counts nonprojectively attached nodes in a-trees in all zones of a given language.
A node is attached nonprojectively if the arc from the parent to the node is nonprojective.
A dependency (arc, edge) is nonprojective if there is a node between (according to word
order) the node and its parent, that is not contained in the subtree rooted by the parent.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

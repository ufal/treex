package Treex::Block::Print::SharedObjects;
use Moose;
use Treex::Core::Common;
use Treex::Core::Cloud;

sub process_zone
{
    my $self  = shift;
    my $zone  = shift;
    my $root  = $zone->get_atree();
    # Convert the tree of nodes to tree of clouds, i.e. build the parallel structure.
    my $cloud = new Treex::Core::Cloud;
    $cloud->create_from_node($root);
    # Traverse the tree of clouds.
    $self->process_cloud($cloud);
    $cloud->destroy_children();
}

sub process_cloud
{
    my $self = shift;
    my $cloud = shift;
    my @participants = $cloud->get_participants();
    my @shared_modifiers = $cloud->get_shared_modifiers();
    # Rekurzi do hloubky dělám tak trochu pro jistotu, ale to, co hledám, bych měl najít vždy těsně pod kořenem.
    foreach my $subcloud (@participants, @shared_modifiers)
    {
        $self->process_cloud($subcloud);
    }
    # Hledáme koordinaci hlavních přísudků, čili uzlů s afunem Pred.
    if($cloud->type() eq 'coordination' && $cloud->afun() eq 'Pred')
    {
        # Zajímají nás společná rozvití předmětem.
        foreach my $child (@shared_modifiers)
        {
            if($child->afun() =~ m/Obj/)
            {
                log_info("Shared object: ".$child->get_address());
            }
        }
    }
}

1;

=over

=item Treex::Block::Print::SharedObjects

Potřebuju si v AGDT ověřit jednu věc kvůli recenzi článku do PBML.

=back

=cut

# Copyright 2013 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

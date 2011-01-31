package Treex::Core::TredView;

# planned to be used from contrib.mac of tred's extensions

use Moose;

has 'grp' => (is => 'rw');
has 'treex_doc' => (is=>'rw');
has 'pml_doc' => (is => 'rw');


sub get_nodelist_hook {
    my ( $self, $fsfile, $treeNo, $currentNode, $hidden ) = @_;

    my $bundle = $fsfile->tree($treeNo);

    my @nodes = map { $_->get_descendants({add_self=>1})}
        map { $_->get_all_trees }
            $bundle->get_all_zones;

    $currentNode = $nodes[0] unless first { $_ == $currentNode } @nodes;
    return [ \@nodes, $currentNode ];

}


sub file_opened_hook {
    my ($self) = @_;
    my $pmldoc = $self->grp()->{FSFile};
    $self->pml_doc($pmldoc);
    $self->treex_doc( Treex::Core::Document->new({pmldoc => $pmldoc}));
}

1;

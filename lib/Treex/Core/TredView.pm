package Treex::Core::TredView;

# planned to be used from contrib.mac of tred's extensions

use Moose;

has 'grp' => (is => 'rw');
has 'treex_doc' => (is=>'rw');
has 'pml_doc' => (is => 'rw');

use List::Util qw(first);

sub get_nodelist_hook {
    my ( $self, $fsfile, $treeNo, $currentNode, $hidden ) = @_;

    return unless $self->pml_doc(); # get_nodelist_hook is invoked also before file_opened_hook

    print "XXX get_nodelist_hook\n";

    my $bundle = $fsfile->tree($treeNo);

    my @nodes = map { $_->get_descendants({add_self=>1})}
        map { $_->get_all_trees }
            $bundle->get_all_zones;

    unshift @nodes, $bundle;

    $currentNode = $nodes[0] unless first { $_ == $currentNode } @nodes;
    return [ \@nodes, $currentNode ];

}


sub file_opened_hook {
    my ($self) = @_;
    my $pmldoc = $self->grp()->{FSFile};

    print "QQQ file_opened_hook\n";

    $self->pml_doc($pmldoc);
    my $treex_doc =  Treex::Core::Document->new({pmldoc => $pmldoc});
    $self->treex_doc($treex_doc);
    print "Treex doc: $treex_doc\n";
    $self->precompute_visualization();
}

sub get_value_line_hook {
    my ( $self, $fsfile, $treeNo ) = @_;
    return unless $self->pml_doc();

    my $bundle = $self->pml_doc->tree($treeNo);
    return join "\n", map {"[".$_->get_label."] ".$_->get_attr('sentence') } grep {defined $_->get_attr('sentence')} $bundle->get_all_zones;
}


# --------------- PRECOMPUTING VISUALIZATION (node labels, styles, coreference links, groups...) ---

sub precompute_visualization {
    my ($self) = @_;
    foreach my $bundle ($self->treex_doc->get_bundles) {
	$self->precompute_bundle_root($bundle);
    }
}


sub precompute_bundle_root {
    my ($self, $bundle) = @_;
    $self->set_line($bundle, 1, 'BUNDLE');
    $self->set_line($bundle, 2, 'is='.$bundle->get_id);
    print "WWW: precompute bundle\n";
}


sub precompute_ttree {
    my ($self, $root) = @_;

}


sub set_line {
    my ($self, $object, $line, $value) = @_;
    $object->{"_precomputed_line".$line} = $value;
}


# ---- END OF PRECOMPUTING VISUALIZATION ------

1;

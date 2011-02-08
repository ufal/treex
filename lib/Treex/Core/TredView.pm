package Treex::Core::TredView;

# planned to be used from contrib.mac of tred's extensions

use Moose;
use Treex::Core::Log;

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

my @layers = qw(a t p n);

sub precompute_visualization {
    my ($self) = @_;
    foreach my $bundle ($self->treex_doc->get_bundles) {

	$bundle->{_precomputed_root_style} = $self->bundle_root_style($bundle);
	$bundle->{_precomputed_labels} = $self->bundle_root_labels($bundle);

	foreach my $zone ($bundle->get_all_zones) {

	    foreach my $layer (@layers)  {
		if ($zone->has_tree($layer)) {
		    my $root = $zone->get_tree($layer);
		    $root->{_precomputed_labels} = $self->tree_root_labels($root);
		    $root->{_precomputed_node_style} = $self->node_style($root,$layer);

		    foreach my $node ($root->get_descendants) {
			$node->{_precomputed_node_style} = $self->node_style($node,$layer);
			$node->{_precomputed_labels} = $self->nonroot_node_labels($node,$layer);
		    }

		}
	    }
	}
    }
}


# ---- info displayed below nodes (should return a reference to a three-element array) ---

sub bundle_root_labels {
    my ($self, $bundle) = @_;
    return [
	'bundle',
	'id='.$bundle->get_id(),
	''
	];
}

sub tree_root_labels {
    my ($self, $root) = @_;
    return [
	$root->get_layer."-tree",
	"zone=".$root->get_zone->get_label,
	''
	];
}

sub nonroot_node_labels { # silly code just to avoid the need for eval
    my $layer = pop @_;
    if ($layer eq 't') {return nonroot_tnode_labels(@_)}
    elsif ($layer eq 'a') {return nonroot_anode_labels(@_)}
    elsif ($layer eq 'n') {return nonroot_nnode_labels(@_)}
    elsif ($layer eq 'p') {return nonroot_pnode_labels(@_)}
    else {log_fatal "Undefined or unknown layer: $layer"}
}


sub nonroot_anode_labels {
    my ($self, $node) = @_;
    return (
	$node->{form},
	$node->{lemma},
	$node->{tag},
	);
}

sub nonroot_tnode_labels {
    my ($self, $node) = @_;
    return (
	$node->{t_lemma},
	$node->{functor},
	$node->{formeme},
	);
}

sub nonroot_nnode_labels {
    return ('','','');
}
sub nonroot_pnode_labels {
    return ('','','');
}
# --- node styling: color, size, shape... of nodes and edges

sub bundle_root_style {
    return "#{nodeXSkip:15} #{nodeYSkip:2} #{lineSpacing:0.7} #{BaseXPos:0} #{BaseYPos:10} #{BalanceTree:1} #{skipHiddenLevels:0}";
}

sub common_node_style {
    return '';
}

sub node_style { # silly code just to avoid the need for eval
    my $layer = pop @_;
    if ($layer eq 't') {return tnode_style(@_)}
    elsif ($layer eq 'a') {return anode_style(@_)}
    elsif ($layer eq 'n') {return nnode_style(@_)}
    elsif ($layer eq 'p') {return pnode_style(@_)}
    else {log_fatal "Undefined or unknown layer: $layer"}
}

sub anode_style {
    my ($self, $node) = @_;
    return "#{Oval-fill:green}";
}

sub tnode_style {
    my ($self, $node) = @_;
    print "PPPPPPPP\n";
    return "#{Oval-fill:blue}";
}

sub nnode_labels {
    return '';
}

sub pnode_labels {
    return '';
}



# ---- END OF PRECOMPUTING VISUALIZATION ------

1;

package Treex::Block::Align::ProjectAlignment;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;
use Clone qw/clone/;

extends 'Treex::Core::Block';

has 'layer' => (is => 'ro', isa => 'Str', default => 't');
has 'trg_layer' => (is => 'ro', isa => 'Str');
has 'trg_selector' => (is => 'ro', isa => 'Str');

has 'aligns' => (is => 'ro', isa => 'Str', required => 1);
has '_aligns_graph' => (is => 'ro', isa => 'HashRef', builder => '_build_aligns_graph', lazy => 1);

sub BUILD {
    my ($self) = @_;
    $self->_aligns_graph;
    if (!defined $self->trg_layer && !defined $self->trg_selector) {
        log_fatal "One of the arguments 'trg_layer' and 'trg_selector' must be specified.";
    }
    if (defined $self->trg_layer && defined $self->trg_selector) {
        log_fatal "Cannot specify both 'trg_layer' and 'trg_selector' arguments.";
    }
    if (defined $self->trg_layer && $self->trg_layer eq $self->layer) {
        log_fatal "Arguments 'layer' and 'trg_layer' must differ.";
    }
    if (defined $self->trg_selector && $self->trg_selector eq $self->selector) {
        log_fatal "Arguments 'selector' and 'trg_selector' must differ.";
    }
}

sub _build_aligns_graph {
    my ($self) = @_;
    my @align_pairs = split /;/, $self->aligns;
    my $aligns_graph = {};
    foreach my $align_pair (@align_pairs) {
        my ($langs, $type_str) = split /:/, $align_pair, 2;
        my ($l1, $l2) = split /-/, $langs, 2;
        my @types = split /,/, $type_str;
        $aligns_graph->{$l1}{$l2} = \@types;
    }
    return $aligns_graph;
}

sub process_bundle {
    my ($self, $bundle) = @_;

    foreach my $l1 (keys %{$self->_aligns_graph}) {
        my $src_tree = $bundle->get_tree($l1, $self->layer, $self->selector);
        foreach my $l2 (keys %{$self->_aligns_graph->{$l1}}) {
            my %src_covered_aligns = ();
            foreach my $node ($src_tree->get_descendants({ordered => 1})) {
                
                my $rel_types = $self->_aligns_graph->{$l1}{$l2};
                my ($src_aligns, $src_ali_types) = $node->get_undirected_aligned_nodes({
                    selector => $node->selector,
                    language => $l2,
                    rel_types => $rel_types,
                });
                $src_covered_aligns{$_->id} = 1 for @$src_aligns;
                
                my ($trg_nodes, $trg_aligns, $trg_ali_types, $trg_nodes_ali_info, $trg_aligns_ali_info);
                # project to the other layer
                if (defined $self->trg_layer) {
                    ($trg_nodes, $trg_aligns, $trg_ali_types, $trg_nodes_ali_info, $trg_aligns_ali_info) = $self->_align_from_other_layer(
                        $node, $src_aligns, $src_ali_types, $self->trg_layer
                    );
                }
                # project to the other selector
                elsif (defined $self->trg_selector) {
                    ($trg_nodes, $trg_aligns, $trg_ali_types, $trg_nodes_ali_info, $trg_aligns_ali_info) = $self->_align_from_other_selector(
                        $node, $src_aligns, $src_ali_types, $self->trg_selector
                    );
                }
                # create projected links
                foreach my $trg_node (@$trg_nodes) {
                    $trg_node->wild->{align_info} = clone($trg_nodes_ali_info) if (defined $trg_nodes_ali_info);
                    for (my $i = 0; $i < @$trg_aligns; $i++) {
                        my $trg_aligned_node = $trg_aligns->[$i];
                        my $trg_ali_type = $trg_ali_types->[$i];
                        $trg_aligned_node->wild->{align_info} = clone($trg_aligns_ali_info->[$i]) if (defined $trg_aligns_ali_info->[$i]);
                        log_info sprintf("Adding alignment of type '%s' between nodes: %s -> %s", $trg_ali_type, $trg_node->id, $trg_aligned_node->id);
                        Treex::Tool::Align::Utils::add_aligned_node($trg_node, $trg_aligned_node, $trg_ali_type);
                    }
                }
            }
            my $align_tree = $bundle->get_tree($l2, $self->layer, $self->selector);
            # run through the nodes from the other language just to find 'align_info' items there and project it
            # TODO: this is horrible
            foreach my $node ($align_tree->get_descendants({ordered => 1})) {
                next if ($src_covered_aligns{$node->id});
                my ($trg_nodes, $trg_aligns, $trg_ali_types, $trg_nodes_ali_info, $trg_aligns_ali_info);
                # project to the other layer
                if (defined $self->trg_layer) {
                    ($trg_nodes, $trg_aligns, $trg_ali_types, $trg_nodes_ali_info, $trg_aligns_ali_info) = $self->_align_from_other_layer(
                        $node, [], [], $self->trg_layer
                    );
                }
                # project to the other selector
                elsif (defined $self->trg_selector) {
                    ($trg_nodes, $trg_aligns, $trg_ali_types, $trg_nodes_ali_info, $trg_aligns_ali_info) = $self->_align_from_other_selector(
                        $node, [], [], $self->trg_selector
                    );
                }
                foreach my $trg_node (@$trg_nodes) {
                    $trg_node->wild->{align_info} = clone($trg_nodes_ali_info) if (defined $trg_nodes_ali_info);
                }
            }
        }
    }
}

sub _get_other_layer_counterpart {
    my ($src_node) = @_;

    my $trg_node;
    if ($src_node->get_layer eq "a") {
        ($trg_node) = $src_node->get_referencing_nodes("a/lex.rf");
    }
    elsif ($src_node->get_layer eq "t") {
        $trg_node = $src_node->get_lex_anode;
    }
    return $trg_node;
}

sub _align_from_other_layer {
    my ($self, $src_node, $src_aligns, $src_ali_types, $trg_layer) = @_;
    
    my $trg_node = _get_other_layer_counterpart($src_node);
    return map {[]} 1..5 if (!defined $trg_node);

    my @trg_aligns = map { _get_other_layer_counterpart($_) } @$src_aligns;
    my @def_idx = grep {defined $trg_aligns[$_]} 0 .. $#trg_aligns;

    my @trg_aligns_def = @trg_aligns[@def_idx];
    my @src_ali_types_arr = @$src_ali_types;
    my @trg_ali_types_def = @src_ali_types_arr[@def_idx];
    my $trg_nodes_info = $src_node->wild->{align_info};
    my @src_aligns_arr = @$src_aligns;
    my @trg_aligns_info = map {$_->wild->{align_info}} @src_aligns_arr[@def_idx];

    return ([$trg_node], \@trg_aligns_def, \@trg_ali_types_def, $trg_nodes_info, \@trg_aligns_info);
}

sub _align_from_other_selector {
    my ($self, $src_node, $src_aligns, $src_ali_types, $trg_selector) = @_;

    my ($trg_nodes, $mono_types) = $src_node->get_undirected_aligned_nodes({
        selector => $trg_selector,
        language => $src_node->language,
    });
    return map {[]} 1..5 if (!@$trg_nodes);

    my $trg_nodes_info = $src_node->wild->{align_info};
    
    #print STDERR Dumper(\@z1_trg_nodes);
    #print STDERR join " ", (map {$_->id} @z1_trg_nodes);
    my @trg_aligns = ();
    my @trg_ali_types = ();
    my @trg_aligns_info = ();
    for (my $i = 0; $i < @$src_aligns; $i++) {
        my $src_aligned_node = $src_aligns->[$i];
        (my $tmp_trg_aligns, $mono_types) = $src_aligned_node->get_undirected_aligned_nodes({
            selector => $trg_selector,
            language => $src_aligned_node->language,
        });
        push @trg_aligns, @$tmp_trg_aligns;
        push @trg_ali_types, ($src_ali_types->[$i]) x scalar @$tmp_trg_aligns;
        push @trg_aligns_info, map {$src_aligned_node->wild->{align_info}} 1 .. scalar @$tmp_trg_aligns;
    }
    
    return ($trg_nodes, \@trg_aligns, \@trg_ali_types, $trg_nodes_info, \@trg_aligns_info);
}

1;

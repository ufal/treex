package Treex::Block::Align::ProjectAlignment;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;

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
        foreach my $node ($src_tree->get_descendants({ordered => 1})) {
            foreach my $l2 (keys %{$self->_aligns_graph->{$l1}}) {
                my $rel_types = $self->_aligns_graph->{$l1}{$l2};
                my ($trg_nodes, $trg_aligns, $trg_ali_types);
                # project to the other layer
                if (defined $self->trg_layer) {
                    ($trg_nodes, $trg_aligns, $trg_ali_types) = $self->_align_from_other_layer(
                        $node, $l2, $self->trg_layer, $rel_types
                    );
                }
                # project to the other selector
                elsif (defined $self->trg_selector) {
                    ($trg_nodes, $trg_aligns, $trg_ali_types) = $self->_align_from_other_selector(
                        $node, $l2, $self->trg_selector, $rel_types
                    );
                }
                # create projected links
                for (my $i = 0; $i < @$trg_aligns; $i++) {
                    my $trg_aligned_node = $trg_aligns->[$i];
                    my $trg_ali_type = $trg_ali_types->[$i];
                    foreach my $trg_node (@$trg_nodes) {
                        log_info sprintf("Adding alignment of type '%s' between nodes: %s -> %s", $trg_ali_type, $trg_node->id, $trg_aligned_node->id);
                        Treex::Tool::Align::Utils::add_aligned_node($trg_node, $trg_aligned_node, $trg_ali_type);
                        $trg_node->wild->{align_info} = $node->wild->{align_info};
                    }
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
    my ($self, $src_node, $trg_lang, $trg_layer, $rel_types) = @_;
    
    my ($src_aligns, $src_ali_types) = $src_node->get_undirected_aligned_nodes({
        selector => $src_node->selector,
        language => $trg_lang,
        rel_types => $rel_types,
    });
    return ([], [], []) if (!@$src_aligns);

    my $trg_node =  _get_other_layer_counterpart($src_node);
    return ([], [], []) if (!defined $trg_node);

    my @trg_aligns = map { _get_other_layer_counterpart($_) } @$src_aligns;
    my @def_idx = grep {defined $trg_aligns[$_]} 0 .. $#trg_aligns;

    my @trg_aligns_def = @trg_aligns[@def_idx];
    my @trg_ali_types = @$src_ali_types;
    my @trg_ali_types_def = @trg_ali_types[@def_idx];

    return ([$trg_node], \@trg_aligns_def, \@trg_ali_types_def);
}

sub _align_from_other_selector {
    my ($self, $src_node, $trg_lang, $trg_selector, $rel_types) = @_;
    
    my ($src_aligns, $src_ali_types) = $src_node->get_undirected_aligned_nodes({
        selector => $src_node->selector,
        language => $trg_lang,
        rel_types => $rel_types,
    });
    return ([], [], []) if (!@$src_aligns);

    my ($trg_nodes, $mono_types) = $src_node->get_undirected_aligned_nodes({
        selector => $trg_selector,
        language => $src_node->language,
    });
    return ([], [], []) if (!@$trg_nodes);
    
    #print STDERR Dumper(\@z1_trg_nodes);
    #print STDERR join " ", (map {$_->id} @z1_trg_nodes);
    my @trg_aligns = ();
    my @trg_ali_types = ();
    for (my $i = 0; $i < @$src_aligns; $i++) {
        my $src_aligned_node = $src_aligns->[$i];
        (my $tmp_trg_aligns, $mono_types) = $src_aligned_node->get_undirected_aligned_nodes({
            selector => $trg_selector,
            language => $trg_lang,
        });
        push @trg_aligns, @$tmp_trg_aligns;
        push @trg_ali_types, ($src_ali_types->[$i]) x scalar @$tmp_trg_aligns;
    }
    
    return ($trg_nodes, \@trg_aligns, \@trg_ali_types);
}

1;

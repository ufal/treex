package Treex::Tool::Align::Utils;

use Moose;
use Treex::Core::Common;
use Data::Dumper;

extends 'Treex::Core::Block';

sub aligned_transitively {
    my ($nodes, $filters) = @_;

    my @level_aligned = @$nodes;

    my $filter;
    while ($filter = shift @$filters) {
        @level_aligned = map {_get_aligned_nodes_by_filter($_, $filter)} @level_aligned;
    }
    return @level_aligned;
}

sub get_alignment_type {
    my ($from, $to) = @_;
    my ($nodes, $types) = $from->get_aligned_nodes();
    my ($type_idx) = grep {$nodes->[$_] == $to} 0 .. scalar(@$nodes)-1;
    return undef if !defined $type_idx;
    return $types->[$type_idx];
}

sub _node_filter_out {
    my ($aligned, $filter) = @_;
    my $lang = $filter->{lang};
    my $sel = $filter->{selector};
    
    return grep {
        (!defined $lang || ($lang eq $_->language)) &&
        (!defined $sel || ($sel eq $_->selector))
    } @$aligned;
}

sub _edge_filter_out {
    my ($aligned, $aligned_types, $filter) = @_;
    my $rel_type = $filter->{rel_type};

    my @idx = grep {
        !defined $rel_type || ($aligned_types->[$_] eq $rel_type)
    } 0 .. scalar(@$aligned)-1;
    return @$aligned[@idx];
}

sub _get_aligned_nodes_by_filter {
    my ($node, $filter) = @_;
    
    # retrieve aligned nodes and its types for both incoming and outcoming links
    my ($aligned_to, $aligned_to_types) = $node->get_aligned_nodes();
    my @aligned_from = $node->get_referencing_nodes('alignment');
    my @aligned_from_types = map {get_alignment_type($_, $node)} @aligned_from;
    my @aligned = ($aligned_to ? @$aligned_to : (), @aligned_from);
    my @aligned_types = ($aligned_to_types ? @$aligned_to_types : (), @aligned_from_types);

    my @edge_filtered = _edge_filter_out(\@aligned, \@aligned_types, $filter);
    my @node_filtered = _node_filter_out(\@edge_filtered, $filter);
    return @node_filtered;
}

sub print_nodes {
    my (@nodes) = @_;
    my @addresses = map {$_->get_address} @nodes;
    print STDERR Dumper(\@addresses);
}

1;

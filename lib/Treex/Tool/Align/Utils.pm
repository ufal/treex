package Treex::Tool::Align::Utils;

use Moose;
use Treex::Core::Common;
use Data::Dumper;

extends 'Treex::Core::Block';

my %SIEVES_HASH = (
    self => \&access_via_self,
    eparents => \&access_via_eparents,
    siblings => \&access_via_siblings,
);

sub add_aligned {
    my ($node1, $node2, $type) = @_;
    #log_info "ALIGN ADD: " . $node2->id;
        
    my $old_type = get_alignment_type($node1, $node2);
    if (!defined $old_type) {
        $node1->add_aligned_node($node2, $type);
        return;
    }

    if ($node1->is_aligned_to($node2, $old_type)) {
        $node1->delete_aligned_node($node2, $old_type);
        $node1->add_aligned_node($node2, "$old_type $type");
    }
    else {
        $node2->delete_aligned_node($node1, $old_type);
        $node2->add_aligned_node($node1, "$old_type $type");
    }
}

sub remove_alignments {
    my ($node1, $filter) = @_;
    my (@aligned) = aligned_transitively([$node1], [$filter]);
    foreach my $node2 (@aligned) {
        #log_info "ALIGN REMOVE: " . $node2->id;
        my $type = get_alignment_type($node1, $node2);
        if ($node1->is_aligned_to($node2, $type)) {
            $node1->delete_aligned_node($node2, $type);
        }
        else {
            $node2->delete_aligned_node($node1, $type);
        }
    }
}

sub aligned_transitively {
    my ($nodes, $filters) = @_;

    my @level_aligned = @$nodes;

    my $filter;
    foreach my $filter (@$filters) {
        @level_aligned = map {_get_aligned_nodes_by_filter($_, $filter)} @level_aligned;
    }
    return @level_aligned;
}

sub get_alignment_type {
    my ($from, $to) = @_;
    my ($nodes, $types) = $from->get_aligned_nodes();
    my $type_idx;
    if (defined $nodes) {
        ($type_idx) = grep {$nodes->[$_] == $to} 0 .. scalar(@$nodes)-1;
    }
    return $types->[$type_idx] if (defined $type_idx);
    # try the opposite link
    ($nodes, $types) = $to->get_aligned_nodes();
    if (defined $nodes) {
        ($type_idx) = grep {$nodes->[$_] == $from} 0 .. scalar(@$nodes)-1;
    }
    return $types->[$type_idx] if (defined $type_idx);
    return;
}

sub _node_filter_out {
    my ($aligned, $filter) = @_;
    my $lang = $filter->{language};
    my $sel = $filter->{selector};
    
    return grep {
        (!defined $lang || ($lang eq $_->language)) &&
        (!defined $sel || ($sel eq $_->selector))
    } @$aligned;
}

sub _value_of_type {
    my ($type, $type_list) = @_;
    my $i = 0;
    foreach my $type_re (@$type_list) {
        return $i if ($type =~ /$type_re/);
    }
    return undef;
}

sub _edge_filter_out {
    my ($aligned, $aligned_types, $filter) = @_;
    my $rel_types = $filter->{rel_types};
    return @$aligned if (!defined $rel_types);
    
    my @values = map {_value_of_type($_, $rel_types)} @$aligned_types;
    my @idx = grep { defined $values[$_] } 0 .. scalar(@$aligned)-1;
    @idx = sort {$values[$a] <=> $values[$b]} @idx;
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

sub aligned_robust {
    my ($tnode, $align_filters, $sieves, $filters) = @_;

    my $errors = [];

    for (my $i = 0; $i < @$sieves; $i++) {
        my $sieve = $sieves->[$i];
        if (ref($sieve) ne "CODE") {
            $sieve = $SIEVES_HASH{$sieve};
        }
        my @aligned = $sieve->($tnode, $align_filters, $errors);
        if (@aligned) {
            my $filter = $filters->[$i];
            return (\@aligned, $errors) if (!defined $filter);
            my @filtered_align = $filter->(\@aligned, $tnode, $errors);
            return (\@filtered_align, $errors) if (@filtered_align);
        }
    }
    return (undef, $errors);
}

sub access_via_self {
    my ($tnode, $align_filters, $errors) = @_;
    my ($aligned_tnode) = aligned_transitively([$tnode], $align_filters);
    if (!defined $aligned_tnode) {
        push @$errors, "NO_CS_REF_TNODE";
        return;
    }
    return $aligned_tnode;
}

sub access_via_eparents {
    my ($tnode, $align_filters, $errors) = @_;

    my @epars = $tnode->get_eparents({or_topological => 1});
    my @aligned_pars = aligned_transitively(\@epars, $align_filters);
    if (!@aligned_pars) {
        push @$errors, "NO_ALIGNED_PARENT";
        return;
    }
    my @aligned_siblings = map {$_->get_echildren({or_topological => 1})} @aligned_pars;
    return @aligned_siblings;
}

sub access_via_siblings {
    my ($tnode, $align_filters, $errors) = @_;

    my @sibs = $tnode->get_siblings();
    if (!@sibs) {
        push @$errors, "NO_SIBLINGS";
        return;
    }
    my @aligned_sibs = aligned_transitively(\@sibs, $align_filters);
    if (!@aligned_sibs) {
        push @$errors, "NO_ALIGNED_SIBLINGS";
        return;
    }
    return @aligned_sibs;
}

sub print_nodes {
    my (@nodes) = @_;
    my @addresses = map {$_->get_address} @nodes;
    print STDERR Dumper(\@addresses);
}

1;

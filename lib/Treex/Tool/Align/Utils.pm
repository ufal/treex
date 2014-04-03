package Treex::Tool::Align::Utils;

use Moose;
use Treex::Core::Common;
use Data::Dumper;
use List::MoreUtils qw/any/;

extends 'Treex::Core::Block';

my %SIEVES_HASH = (
    self => \&access_via_self,
    eparents => \&access_via_eparents,
    siblings => \&access_via_siblings,
);

sub are_aligned {
    my ($node1, $node2, $filter) = @_;

    my ($nodes, $types) = get_aligned_nodes_by_filter($node1, $filter);
    return any {$_ == $node2} @$nodes;
}

sub get_aligned_nodes_by_filter {
    my ($node, $filter) = @_;
    
    # retrieve aligned nodes and its types for both incoming and outcoming links
    my ($aligned_to, $aligned_to_types) = $node->get_aligned_nodes();
    #log_info "ALITO: " . Dumper($aligned_to_types);
    #log_info "ALITOIDS: " . (join ",", map {$_->id} @$aligned_to);
    my @aligned = $aligned_to ? @$aligned_to : ();
    my @aligned_types = $aligned_to_types ? @$aligned_to_types : ();
    
    if (!$filter->{directed}) {
        my @aligned_from = $node->get_referencing_nodes('alignment');
        my @aligned_from_types = map {get_alignment_types($_, $node)} @aligned_from;
    #log_info "ALIFROM: " . Dumper(\@aligned_from_types);
    #log_info "ALIFROMIDS: " . (join ",", map {$_->id} @aligned_from);
        push @aligned, @aligned_from;
        push @aligned_types, @aligned_from_types;
    }

    my ($edge_nodes, $edge_types) = _edge_filter_out(\@aligned, \@aligned_types, $filter);
    my ($filtered_nodes, $filtered_types) = _node_filter_out($edge_nodes, $edge_types, $filter);
   
    return ($filtered_nodes, $filtered_types);
}

sub remove_aligned_nodes_by_filter {
    my ($node, $filter) = @_;

    my ($nodes, $types) = get_aligned_nodes_by_filter($node, $filter);
    for (my $i = 0; $i < @$nodes; $i++) {
        #log_info "ALIGN REMOVE: " . $types->[$i] . " " . $nodes->[$i]->id;
        if ($node->is_aligned_to($nodes->[$i], $types->[$i])) {
            $node->delete_aligned_node($nodes->[$i], $types->[$i]);
        }
        else {
            $nodes->[$i]->delete_aligned_node($node, $types->[$i]);
        }
    }
}

sub _node_filter_out {
    my ($nodes, $types, $filter) = @_;
    my $lang = $filter->{language};
    my $sel = $filter->{selector};

    my @idx = grep {
        (!defined $lang || ($lang eq $nodes->[$_]->language)) &&
        (!defined $sel || ($sel eq $nodes->[$_]->selector))
    } 0 .. $#$nodes;

    return ([@$nodes[@idx]], [@$types[@idx]]);
}

sub _value_of_type {
    my ($type, $type_list) = @_;
    my $i = 0;
    foreach my $type_re (@$type_list) {
        if ($type_re =~ /^!(.*)/) {
            return undef if ($type =~ /$1/);
        }
        else {
            return $i if ($type =~ /$type_re/);
        }
        $i++;
    }
    return undef;
}

sub _edge_filter_out {
    my ($nodes, $types, $filter) = @_;
    my $rel_types = $filter->{rel_types};
    return ($nodes, $types) if (!defined $rel_types);
    
    #log_info 'ALITYPES: ' . Dumper($types);
    my @values = map {_value_of_type($_, $rel_types)} @$types;
    #log_info 'ALITYPES: ' . Dumper(\@values);
    my @idx = grep { defined $values[$_] } 0 .. scalar(@$nodes)-1;
    @idx = sort {$values[$a] <=> $values[$b]} @idx;

    return ([@$nodes[@idx]], [@$types[@idx]]);
}

sub add_aligned_node {
    my ($node1, $node2, $type) = @_;
    #log_info "ALIGN ADD: " . $node2->id;
        
    my @old_types = get_alignment_types($node1, $node2);
    my $type_defined = any {$_ eq $type} @old_types;
    if (!$type_defined) {
        #log_info "ADD_ALIGN: $type " . $node2->id;
        $node1->add_aligned_node($node2, $type);
    }

    #if ($node1->is_aligned_to($node2, $old_type)) {
    #    $node1->delete_aligned_node($node2, $old_type);
    #    $node1->add_aligned_node($node2, "$old_type $type");
    #}
    #else {
    #    $node2->delete_aligned_node($node1, $old_type);
    #    $node2->add_aligned_node($node1, "$old_type $type");
    #}
}

sub get_alignment_types {
    my ($from, $to, $both_dir) = @_;

    my @all_types;
    my @types_idx;
    
    my ($nodes, $types) = $from->get_aligned_nodes();
    if (defined $nodes) {
        @types_idx = grep {$nodes->[$_] == $to} 0 .. scalar(@$nodes)-1;
    }
    push @all_types, @$types[@types_idx];
    
    # try the opposite link
    if ($both_dir) {
        ($nodes, $types) = $to->get_aligned_nodes();
        if (defined $nodes) {
            @types_idx = grep {$nodes->[$_] == $from} 0 .. scalar(@$nodes)-1;
        }
        push @all_types, @$types[@types_idx];
    }
    
    return @all_types;
}

sub aligned_transitively {
    my ($nodes, $filters) = @_;

    my @level_aligned = @$nodes;

    my $filter;
    foreach my $filter (@$filters) {
        @level_aligned = map {my ($n, $t) = get_aligned_nodes_by_filter($_, $filter); @$n;} @level_aligned;
    }
    return @level_aligned;
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
            #print STDERR "FILTER_" . $i . ": " . $filtered_align[0]->get_address . "\n" if (@filtered_align);
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

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
    
    # retrieve aligned nodes and its types outcoming links
    
    my ($aligned_to, $aligned_to_types) = $node->get_aligned_nodes();
    #log_info "ALITO: " . Dumper($aligned_to_types);
    #log_info "ALITOIDS: " . (join ",", map {$_->id} @$aligned_to);
    my @aligned = $aligned_to ? @$aligned_to : ();
    my @aligned_types = $aligned_to_types ? @$aligned_to_types : ();
    
    # retrieve aligned nodes and its types outcoming links
    
    if (!$filter || !$filter->{directed}) {
        my @aligned_from = sort {$a->id cmp $b->id} $node->get_referencing_nodes('alignment');
        my %seen_ids = ();
        my @aligned_from_types = map {get_alignment_types($_, $node)} grep {!$seen_ids{$_->id}++} @aligned_from;
        #log_info "ALIFROM: " . Dumper(\@aligned_from_types);
        #log_info "ALIFROMIDS: " . (join ",", map {$_->id} @aligned_from);
        push @aligned, @aligned_from;
        push @aligned_types, @aligned_from_types;
    }

    # filter the retrieved nodes and links

    my ($final_nodes, $final_types) = (\@aligned, \@aligned_types);
    if ($filter) {
        ($final_nodes, $final_types) = _edge_filter_out($final_nodes, $final_types, $filter);
        ($final_nodes, $final_types) = _node_filter_out($final_nodes, $final_types, $filter);
    }
  
    log_debug "[Tool::Align::Utils::get_aligned_nodes_by_filter]\tfiltered: " . (join " ", @$final_types), 1;
    return ($final_nodes, $final_types);
}

sub remove_aligned_nodes_by_filter {
    my ($node, $filter) = @_;

    my ($nodes, $types) = get_aligned_nodes_by_filter($node, $filter);
    for (my $i = 0; $i < @$nodes; $i++) {
        log_debug "[Tool::Align::Utils::remove_aligned_nodes_by_filter]\tremoving: " . $types->[$i] . " " . $nodes->[$i]->id, 1;
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
            return undef if ($type =~ /^$1$/);
        }
        else {
            return $i if ($type =~ /^$type_re$/);
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
    my @idx = grep { defined $values[$_] } 0 .. $#$nodes;
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

__END__

=head1 NAME

Treex::Tool::Align::Utils

=head1 SYNOPSIS

 use Treex::Tool::Align::Utils;

 my ($ali_nodes, $ali_types) = Treex::Tool::Align::Utils::get_aligned_nodes_by_filter(
    $tnode,
    { language => 'en', selector => 'src', rel_types => ['!gold','!supervised','.*'] }
 );
 
 
=head1 DESCRIPTION

Even though word-alignment is considered to be non-directional, Treex natively represents
alignment between two nodes as a directed link. This module offers a set of functions
that enables the user to ask for alignment link without bothering about what is the direction
of alignment links in the particular document.

=head1 FUNCTIONS

=over

=item ($ali_nodes, $ali_types) = get_aligned_nodes_by_filter($node, $filter)

This is the main getter method. It returns all nodes aligned to a specified node C<$node>,
and types of these alignment links as two list references -- C<$ali_nodes>, and C<$ali_types>,
respectively. By the parameter C<$filter>, one may specify a filter to be applied to the nodes
and links. The filter is a hash reference, with the following possible keys:
 
C<language> - the language of the aligned nodes (e.g. C<en>)
C<selector> - the selector of the aligned nodes (e.g. C<src>)
C<directed> - return only the links originating from the C<$node> (possible values: C<0> and C<1>)
C<rel_types> - filter the alignment types. The value of this parameter must be a reference to
a list of regular expression strings. The expressions starting with the C<!> sign represent negative
filters. The actual link type is compared to these regexps one after another, skipping the rest
if the type matches a current regexp. If the type matches no regexps in the list, it is filtered out.
Therefore, negative rules should be at the beginning of the list, followed by at least one positive
rule. For instance, C<['a','b']> returns only links of type C<a> or C<b>. On the other hand, 
C<['!a','!b','.*']> returns everything except for C<a> and C<b>. The filter C<['!ab.*','a.*']>
accepts only the types starting with C<a>, except for those starting with C<ab>.
                

Both returned list references -- C<$ali_nodes> and C<$ali_types>, are always defined. If the
C<$node> has no alignment link that satisfies the filter constraints, a reference to an empty
list is returned.

=item $bool = are_aligned($node1, $node2, $filter)

An indicator function of whether the nodes C<$node1> and C<$node2> are aligned under the conditions
specified by the filter C<$filter> (see more in the C<get_aligned_nodes_by_filter> function description).

=item remove_aligned_nodes_by_filter($node, $filter)

This deletes the alignment links pointing from/to the node C<$node>. Only the links satisfying
the C<$filter> constraints are removed.

=back

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-15 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

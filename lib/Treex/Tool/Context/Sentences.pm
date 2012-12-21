package Treex::Tool::Context::Sentences;

use Moose;

has 'nodes_within_czeng_blocks' => (
    isa => 'Bool',
    is  => 'ro',
    required => 1,
    default => 0,
);

sub nodes_in_surroundings {
    my ($self, $node, $start_offset, $end_offset, $arg_ref) = @_;

    return () if ($start_offset > $end_offset);
    ($start_offset, $end_offset) = $self->_adjust_to_args($start_offset, $end_offset, $arg_ref);

    my $sent_num = $node->get_bundle->get_position;
    my @range = ();
    if ($start_offset <= 0 && $end_offset >= 0) {
        my @previous = $self->_nodes_of_same_kind_in_range(
            $node, $sent_num + $start_offset, $sent_num - 1
        );
        my @next = $self->_nodes_of_same_kind_in_range(
            $node, $sent_num + 1, $sent_num + $end_offset
        );
        
        my @current = $self->_nodes_in_current_sent($node, $arg_ref);
        @range = ( @previous, @current, @next );
    }
    else {
        @range = $self->_nodes_of_same_kind_in_range(
            $node, $sent_num + $start_offset, $sent_num + $end_offset
        );
    }
    return @range;
}

sub _adjust_to_args {
    my ($self, $start, $end, $args) = @_;
    if ($args->{preceding_only} && ($end > 0)) {
        $end = 0;
    }
    if ($args->{following_only} && ($start < 0)) {
        $start = 0;
    }
    return ($start, $end);
}

sub _nodes_of_same_kind_in_range {
    my ($self, $node, $start, $end) = @_;

    my @bundles = $self->bundles_in_range($node->get_document, $start, $end);
    @bundles = $self->_remove_bundles_out_czeng_blocks($node, @bundles);
    my @nodes = $self->_extract_nodes_of_same_kind($node, @bundles);

    return @nodes;
}

sub _remove_bundles_out_czeng_blocks {
    my ($self, $node, @bundles) = @_;

    # remove bundles which are in a block different to the anphor's one
    if ($self->nodes_within_czeng_blocks) {
        my $block_id = $node->get_bundle->attr('czeng/blockid');
        if (defined $block_id) {
            @bundles = grep {$_->attr('czeng/blockid') eq $block_id} @bundles;
        }
    }
    return @bundles;
}

sub _nodes_in_current_sent {
    my ($self, $node, $arg_ref) = @_;
    
    my @all_nodes = $node->get_root->get_descendants( { ordered => 1 } );
    my @nodes = ();
    
    # TODO Treex::Core::Node::_process_args could be reused here
    if ( $arg_ref->{add_self} ) {
        push @nodes, $node;
    }
    my @preceding = grep {$_->precedes($node)} @all_nodes;
    my @following = grep {$node->precedes($_)} @all_nodes;
    if ( $arg_ref->{preceding_only} ) {
        unshift @nodes, @preceding;
    }
    elsif ( $arg_ref->{following_only} ) {
        push @nodes, @following;
    }
    else {
        unshift @nodes, @preceding;
        push @nodes, @following;
    }
    
    return @nodes;
}

sub bundles_in_range {
    my ($self, $doc, $start, $end) = @_;

    return () if ($start > $end);

    my @all_bundles = $doc->get_bundles;
    my $last_idx = (scalar @all_bundles) - 1;

    $start = 0 if ($start < 0);
    $end = $last_idx if ($end > $last_idx);

    my @bundles = @all_bundles[ $start .. $end ];
    return @bundles;
}

sub _extract_nodes_of_same_kind {
    my ($self, $node, @bundles) = @_;
    
    my @nodes;

    my @trees   = map {
        $_->get_tree( $node->language, $node->get_layer, $node->selector )
    } @bundles;
    foreach my $tree (@trees) {
        push @nodes, $tree->get_descendants({ ordered => 1 });
    }

    return @nodes;
}

1;

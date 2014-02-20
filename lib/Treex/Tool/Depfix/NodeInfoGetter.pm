package Treex::Tool::Depfix::NodeInfoGetter;
use Moose;
use Treex::Core::Common;
use utf8;

has attributes => ( is => 'rw', isa => 'ArrayRef',
    default => sub { ['form', 'lemma', 'tag', 'afun'] } );

my %getnode = (
    node => sub { $_[0] },
    parent => sub { $_[0]->get_eparents(
            {first_only => 1, or_topological => 1} )
    },
    grandparent => sub { $_[0]->get_eparents(
            {first_only => 1, or_topological => 1}
        )->get_eparents( {first_only => 1, or_topological => 1} )
    },
    precchild => sub { $_[0]->get_echildren(
            {last_only => 1, preceding_only => 1, or_topological => 1} )
    },
    follchild => sub { $_[0]->get_echildren(
            {first_only => 1, following_only => 1, or_topological => 1} )
    },
    precnode => sub { $_[0]->get_prev_node() },
    follnode => sub { $_[0]->get_next_node() },
);

sub add_info {
    my ($self, $info, $prefix, $node, $names) = @_;

    $prefix = $prefix . '_';

    if ( !defined $names ) {
        $names = ['node', 'parent', 'grandparent', 'precchild', 'follchild', 'precnode', 'follnode'];
    }

    foreach my $name (@$names) {
        my $namednode = $getnode{$name}($node);
        $self->add_node_info($info, $prefix.$name, $namednode);
    }

    return;
}

sub add_node_info {
    my ($self, $info, $prefix, $node) = @_;

    $prefix = $prefix . '_' ;

    if ( defined $node && !$node->is_root() ) {
        foreach my $attribute (@{$self->attributes}) {
            $info->{$prefix.$attribute} = $node->get_attr($attribute);
        }
        $info->{$prefix.'edgedirection'} = $node->precedes( $getnode{parent}($node) ) ? '/' : '\\';
        $info->{$prefix.'childno'} = scalar($node->get_echildren({or_topological => 1}));
        $info->{$prefix.'lchildno'} = scalar($node->get_echildren({preceding_only=>1, or_topological => 1}));
        $info->{$prefix.'rchildno'} = scalar($node->get_echildren({following_only=>1, or_topological => 1}));
        $self->add_tag_split($info, $prefix, $node);
    } else {
        foreach my $attribute (@{$self->attributes}) {
            $info->{$prefix.$attribute} = '';
        }
        $info->{$prefix.'edgedirection'} = '';
        $info->{$prefix.'childno'} = '';
        $info->{$prefix.'lchildno'} = '';
        $info->{$prefix.'rchildno'} = '';
        $self->add_tag_split($info, $prefix, undef);
    }

    return;
}

sub add_tag_split {
    my ($self, $info, $prefix, $node) = @_;

    # nothing done by default
    # may be overridden for a specific language or tagset

    return;
}

sub add_edge_existence_info {
    my ($self, $info, $prefix, $child, $parent) = @_;
    
    $prefix = $prefix . '_' ;

    if ( !defined $child || !defined $parent ) {
        # not even the nodes exist
        $info->{$prefix.'existence'} = '';
    } else {
        # existence
        my @child_parents = $child->get_eparents( {or_topological => 1} );
        my @parent_parents = $parent->is_root ? () : $parent->get_eparents( {or_topological => 1} );
        if ( grep { $_->id eq $parent->id } @child_parents ) {
            # the edge exists
            $info->{$prefix.'existence'} = 1;
        } elsif ( grep { $_->id eq $child->id } @parent_parents ) {
            # an inverse edge exists
            $info->{$prefix.'existence'} = -1;
        } else {
            # the edge does not exist
            $info->{$prefix.'existence'} = 0;
        }
    }

    return;
}



1;

=head1 NAME

Treex::Tool::Depfix::NodeInfoGetter

=head1 DESCRIPTION

A Depfix block.

Provides methods to get node information in hashes.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


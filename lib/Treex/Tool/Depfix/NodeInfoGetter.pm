package Treex::Tool::Depfix::NodeInfoGetter;
use Moose;
use Treex::Core::Common;
use utf8;

has attributes => ( is => 'rw', isa => 'ArrayRef',
    default => sub { ['form', 'lemma', 'tag', 'afun'] } );

sub add_node_info {
    my ($self, $info, $prefix, $anode, $splittag) = @_;

    if ( defined $anode && !$anode->is_root() ) {
        foreach my $attribute (@{$self->attributes}) {
            $info->{$prefix.$attribute} = $anode->get_attr($attribute);
        }
        $info->{$prefix.'childno'} = scalar($anode->get_echildren({or_topological => 1}));
        if ( $splittag ) {
            $self->add_tag_split($info, $prefix, $anode);
        }
    } else {
        foreach my $attribute (@{$self->attributes}) {
            $info->{$prefix.$attribute} = '';
        }
        $info->{$prefix.'childno'} = '';
        if ( $splittag ) {
            $self->add_tag_split($info, $prefix, undef);
        }
    }

    return;
}

sub add_tag_split {
    my ($self, $info, $prefix, $anode) = @_;

    # nothing done by default
    # may be overridden for a specific language or tagset

    return;
}

sub add_edge_info {
    my ($info, $prefix, $child, $parent) = @_;
    
    if ( !defined $child || !defined $parent ) {
        # not even the nodes exist
        $info->{$prefix.'existence'} = '';
        $info->{$prefix.'direction'} = '';
    } else {
        # direction (more of node precedence, the edge does not have to exist)
        $info->{$prefix.'direction'} = $child->precedes($parent) ? '/' : '\\';
        # existence
        my @child_parents = $child->get_eparents( {or_topological => 1} );
        my @parent_parents = $parent->get_eparents( {or_topological => 1} );
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


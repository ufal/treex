package Treex::Block::A2A::Transform::CoordStyle;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

has family => (
    is            => 'ro',
    default       => 'Moscow',
    documentation => 'output coord style family (Prague, Moscow, and Stanford)',
);

# TODO "detect" option
has from_family => (
    is            => 'ro',
    default       => 'Prague',
    documentation => 'input coord style family (Prague, Moscow, and Stanford)',
);

# previous, following, between
has comma => (
    is            => 'ro',
    default       => 'previous',
    documentation => 'comma parents (previous, following, between)',
);

# previous, following, between
has conjunction => (
    is            => 'ro',
    default       => 'between',
    documentation => 'conjunction parents (previous, following, between)',
);

# left, right, nearest
has head => (
    is            => 'ro',
    default       => 'left',
    documentation => 'which node should be the head of the coordination structure',
);

# head, nearest
has shared => (
    is            => 'ro',
    default       => 'nearest',
    documentation => 'which node should be the head of the shared modifiers',
);

sub process_atree {
    my ( $self, $atree ) = @_;
    $self->process_subtree($atree);
}

sub _empty_res {
    return ( members => [], shared => [], commas => [], ands => [] );
}

sub _merge_res {
    my ( $self, @results ) = @_;
    my $merged_res = $self->_empty;
    foreach my $res ( grep {$_} @results ) {
        foreach my $type ( keys %{$merged_res} ) {
            push @{ $merged_res->{$type} }, @{ $res->{$type} };
        }
    }
    return $merged_res;
}

# returns $res
sub process_subtree {
    my ( $self, $node ) = @_;
    my @children = $node->get_children();
    if ( !@children ) {
        my $type = $self->type_of_node($node) or return 0;
        return { $self->_empty_res, $type => [$node] };
    }

    # recursively process children subtrees
    my @child_res = grep {$_} map { $self->process_subtree($_) } @children;

    my $my_type = $self->type_of_node($node);
    if ( !$my_type ) {
        foreach my $child (@children) {
            $self->transform_coord( $node, $self->process_subtree($child) );
        }
        return 0;
    }

    # So $my_type is not empty
    my $parent      = $node->get_parent();
    my $parent_type = $self->type_of_node($parent);
    my $from_f      = $self->from_family;
#    if ( $from_f eq 'detect' ) {
#        if ( $my_type eq 'ands' ) {
#            if ( $parent_type ne 'members' && !$self->is_conjunction($parent) ) {
#                $from_f = 'Prague';
#            }
#        }
#        elsif (1) {
#
#        }
#    }

    my $merged_res = $self->_merge_res(@child_res);

    if ( $from_f eq 'Prague' && $my_type eq 'ands' ) {

    }

    foreach my $child (@children) {
        my $res = $self->process_subtree($child) or next;
        my $child_type = $self->type_of_node($child);
        if ( !$my_type ) {
            $self->transform_coord( $node, $res );
        }
        elsif ($child_type) {

            #TODO!!!
        }
    }
    return $merged_res;
}

sub type_of_node {
    my ( $self, $node ) = @_;
    return 'members' if $node->is_member;
    return 'shared'  if $node->is_shared_modifier;
    return 'ands'    if $self->is_conjunction($node);
    return 'commas'  if $self->is_comma($node);
    return 0;
}

# returns new_head
sub transform_coord {
    my ( $self, $orig_head, $res ) = @_;
    return $orig_head if !$res;
    my $parent  = $orig_head->get_parent();
    my @members = sort {$_->ord <=> $_->ord} @{ $res->{members} };
    if ( !@members ) {
        log_warn "No conjuncts in coordination under " . $parent->get_address;
        return $orig_head;
    }
    my @shared      = @{ $res->{shared} };
    my $parent_left = $parent->precedes( $members[0] );
    my $first       = $self->head eq 'left' ? 1 : $self->head eq 'right' ? 0 : $parent_left;

    if ( $self->family eq 'Prague' ) {
        my @separators = ( @{ $res->{ands} }, @{ $res->{commas} } );
        if ( !@separators ) {
            log_warn "No separators in coordination under " . $parent->get_address;
            return $orig_head;
        }

        my $head = $first ? shift @separators : pop @separators;
        $self->rehang( $head, $parent );
        $head->set_afun('Coord');

        foreach my $member (@members) {
            $self->rehang( $member, $head );
        }

        foreach my $sep (@separators) {
            $sep->set_afun( $self->is_comma($sep) ? 'AuxX' : 'AuxY' );
            if ( $self->comma eq 'between' ) {
                $self->rehang( $sep, $head );
            }
            elsif ($self->comma eq 'previous') {
                my $prev_mem = first {$_->precedes($sep)} reverse @members;
                if (!$prev_mem){
                    $prev_mem = first {$sep->precedes($_)} @members;
                }
                $self->rehang( $sep, $prev_mem );
            } else { # $self->comma eq 'following'
                my $foll_mem = first {$sep->precedes($_)} @members;
                if (!$foll_mem){
                    $foll_mem = first {$_->precedes($sep)} reverse @members;
                }
                $self->rehang( $sep, $foll_mem );
            }
        }

        foreach my $sm (@shared) {
            if ( $self->shared eq 'head' ) {
                $self->rehang( $sm, $head );
            }
            else {

                # TODO nearest member
            }
        }
        return $head;
    }
    # TODO Stanford, Moscow
    return $orig_head;
}

# Is the given node a coordination separator such as comma or semicolon?
sub is_comma {
    my ( $self, $node ) = @_;

    #return $node->afun =~ /Aux[XYG]/;
    return $node->form =~ /^[,;]$/;
}

# Is the given node a coordination conjunction?
sub is_conjunction {
    my ( $self, $node ) = @_;
    return 1 if $node->afun eq 'Coord';
    return 1 if $node->afun eq 'AuxY' && $node->get_iset('subpos') eq 'coor';
    return 0;
}

1;

__END__

=head1 NAME

Treex::Block::A2A::Transform::CoordStyle - change the style of coordinations

=head1 SYNOPSIS

  # in scenario:
  A2A::Transform::CoordStyle
         family=Moscow
           head=left
         shared=nearest
    conjunction=between
          comma=previous

  #TODO the same using a shortcut
  #A2A::Transform::CoordStyle style=fMhLsNcBpP
  
=head1 DESCRIPTION

TODO

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

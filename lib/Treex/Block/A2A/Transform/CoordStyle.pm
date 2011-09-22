package Treex::Block::A2A::Transform::CoordStyle;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

has family => (
    is            => 'ro',
    default       => 'Moscow',
    documentation => 'output coord style family (Prague, Moscow, and Stanford)',
);

#has from_family => (
#    is            => 'ro',
#    default       => 'Prague',
#    documentation => 'input coord style family (Prague, Moscow, and Stanford)',
#);

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

# first, last, nearest
has head => (
    is            => 'ro',
    default       => 'first',
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

my @empty = ( members => [], shared => [], commas => [], ands => [] );

sub process_subtree {
    my ( $self, $node ) = @_;
    my @children = $node->get_children();
    if ( !@children ) {
        my $type = $self->type_of_node($node) or return;
        return { @empty, $type => [$node] };
    }

    my $my_type = $self->type_of_node($node);
    foreach my $child (@children) {
        my $res = $self->process_subtree($child) or next;
        my $child_type = $self->type_of_node($child);
        if ( !$my_type ) {
            $self->transform_coord( $node, $res );
        }
        else {

            #TODO!!!
        }
    }
    return;
}

sub type_of_node {
    my ( $self, $node ) = @_;
    return 'members' if $node->is_member;
    return 'shared'  if $node->is_shared_modifier;
    return 'ands'    if $self->is_conjunction($node);
    return 'commas'  if $self->is_comma($node);
    return 0;
}

sub transform_coord {
    my ( $self, $parent, $res ) = @_;
    my @members = @{ $res->{members} };
    if ( !@members ) {
        log_warn "No conjuncts in coordination under " . $parent->get_address;
        return;
    }
    my @shared      = @{ $res->{shared} };
    my $parent_left = $parent->precedes( $members[0] );
    my $first       = $self->head eq 'first' ? 1 : $self->head eq 'last' ? 0 : $parent_left;

    if ( $self->family eq 'Prague' ) {
        my @separators = ( @{ $res->{ands} }, @{ $res->{commas} } );
        if ( !@separators ) {
            log_warn "No separators in coordination under " . $parent->get_address;
            return;
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
            else {

                #TODO
            }
        }
        
        foreach my $sm (@shared) {
            if ($self->shared eq 'head') {
                $self->rehang( $sm, $head );
            } else {
                # TODO nearest member
            }
        }

    }

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
           head=first
         shared=first
    conjunction=between
          comma=previous

  #TODO the same using a shortcut
  #A2A::Transform::CoordStyle style=fMhFsFcBoP
  
=head1 DESCRIPTION

TODO

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::A2A::Transform::CoordStyle;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

has family => (
    is            => 'ro',
    default       => 'Moscow',
    documentation => 'output coord style family (Prague, Moscow, and Stanford)',
);

has from_family => (
    is            => 'ro',
    default       => 'Prague',
    documentation => 'input coord style family (Prague, Moscow, and Stanford)',
);

# TODO first last nearest
has head => (
    is            => 'ro',
    default       => 'first',
    documentation => 'which node should be the head of the coordination structure',
);

sub process_atree {
    my ( $self, $atree ) = @_;
    $self->process_subtree($atree);
}

sub process_subtree {
    my ( $self, $node ) = @_;
    my $info = { members => [], shared => [], commas => [], ands => [], todo => [] };
    if ( $node->afun eq 'Coord' ) {
        $self->detect_prague( $node, $info );
    }
    elsif ( $node->is_member ) {
        $self->detect_nonprague( $node, $info );
    }
    $self->transform_coord( $node, $info );

    foreach my $child ( @{ $info->{todo} } ) {
        $self->process_subtree($child);
    }
    return;
}

#use List::MoreUtils qw(part);
#  my ( $mem, $sha, $other ) =
#  part { $_->is_member ? 0 : $_->is_shared_modifier ? 1 : 2 } @children;

sub detect_prague {
    my ( $self, $node, $info ) = @_;
    push @{ $info->{ands} }, $node;

    foreach my $child ( $node->get_children() ) {
        if ( $child->is_member ) {
            push @{ $info->{members} }, $child;
            if ($child->afun eq 'Coord'){
                push @{ $info->{todo} }, $child;
            } else {
                push @{ $info->{members} }, grep {$_->is_shared_modifier} $child->get_children();
                push @{ $info->{todo} }, grep {!$_->is_shared_modifier} $child->get_children();
            }
        }
        elsif ( $child->is_shared_modifier ) {
            push @{ $info->{shared} }, $child;
            push @{ $info->{todo} }, $child->get_children();
        }
        else {
            push @{ $info->{commas} }, $child;
            push @{ $info->{todo} }, $child->get_children();
        }
    }
    return;
}

sub detect_nonprague {
    my ( $self, $node, $info ) = @_;
    push @{ $info->{members} }, $node;

    foreach my $child ( $node->get_children() ) {
        
    }
    return;
}

# Is the given node a coordination separator such as comma or semicolon?
sub is_comma {
    my ( $self, $node ) = @_;
    return $node->afun =~ /Aux[XYG]/;
}

# Is the given node a coordination conjunction?
sub is_conjunction {
    my ( $self, $node ) = @_;

    # In future, we may add other rules for other families
    #return 1 if $self->from_family eq 'Prague' && $self->afun eq 'Coord';
    return $node->afun eq 'Coord';
}

0; #Not ready yet

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

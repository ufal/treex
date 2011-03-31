package Treex::Block::Util::DefinedAttr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has [qw(tnode anode nnode pnode)] => (
    is            => 'ro',
    documentation => 'comma separated attributes of nodes on a given layer',
);

has 'on_error' => (
    is            => 'ro',
    isa           => enum( [qw(warn die)] ),
    default       => 'warn',
    documentation => 'What to do if undefined attributes are found: warn or die',
);

has 'message' => (
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'What to print',
);

sub BUILD {
    my ($self) = @_;
    if ( !$self->tnode && !$self->anode && !$self->nnode && !$self->pnode ) {
        log_fatal 'One of parameters tnode, anode, nnode, pnode must be specified.';
    }
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    if ( $self->anode ) { $self->check_tree( $zone, 'a', $self->anode ); }
    if ( $self->tnode ) { $self->check_tree( $zone, 't', $self->tnode ); }
    if ( $self->nnode ) { $self->check_tree( $zone, 'n', $self->nnode ); }
    if ( $self->pnode ) { $self->check_tree( $zone, 'p', $self->pnode ); }
    return;
}

sub check_tree {
    my ( $self, $zone, $layer, $attrs ) = @_;
    my $tree = $zone->get_tree($layer);
    if ( !defined $tree ) {
        log_warn "No $layer-tree in zone " . $zone->get_label();
        return;
    }

    foreach my $node ( $tree->get_descendants() ) {
        foreach my $name ( split /,/, $attrs ) {
            my $value = $node->get_attr($name);
            if ( !defined $value ) {
                my $id = $node->id || '?';

                #TODO print doc name, bundle id etc.
                my $msg = "${layer}node id=$id\tattr_name=$name\t" . $self->message;
                log_fatal($msg) if $self->on_error eq 'die';
                log_warn($msg);
            }
        }
    }
    return;
}

1;

__END__

=for Pod::Coverage check_tree

=head1 NAME

Treex::Block::Util::DefinedAttr - Special block for checking undef attributes

=head1 SYNOPSIS

  # on the command line:
  treex Util::DefinedAttr anode=lemma on_error=die -- myfile.treex

  # in a scenario:
  Util::SetGlobal language=en selector=T 
  Util::DefinedAttr tnode=t_lemma,nodetype,formeme
  Block::XY
  Util::DefinedAttr anode=lemma on_error=die message="after block XY"


=head1 DESCRIPTION

Warns/dies if a given attribute is undefined (in any node).

One of parameters tnode, anode, nnode, pnode must be always specified.
By default: on_error=warn and message is empty.


=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

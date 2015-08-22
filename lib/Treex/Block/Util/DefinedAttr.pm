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
    isa           => enum( [qw(warn die ignore)] ),
    default       => 'warn',
    documentation => 'What to do if undefined attributes are found: warn (default), die, ignore',
);

has 'message' => (
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'What to print',
);

has fill => (
    isa => 'Str',
    is => 'ro',
    default => 'undef',
    documentation => 'Comma separated list of attribute values to be filled instead of undef. The default is "undef" which means Perl undef. If this list is shorter than ?node list, the last value is used for the rest. '
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
        my @fill_values = split /,/, $self->fill;

        # If $self->fill is an empty string, @fill_values will contain no items.
        @fill_values = ('') if !@fill_values;

        my $fill_value = shift @fill_values;
        foreach my $name ( split /,/, $attrs ) {
            my $orig_value = $node->get_attr($name);
            if ( !defined $orig_value ) {
                if ($self->on_error =~ /die|warn/){
                    my $address = $node->get_address();
                    my $msg     = "${layer}node\t$address\tundefined attr_name=$name\t" . $self->message;
                    log_fatal($msg) if $self->on_error eq 'die';
                    log_warn($msg);
                }
                $node->set_attr($name, $fill_value) if $fill_value ne 'undef';
            }
            $fill_value = shift @fill_values if @fill_values;
        }
    }
    return;
}

1;

__END__

=pod

=encoding utf-8

=for Pod::Coverage check_tree

=head1 NAME

Treex::Block::Util::DefinedAttr - Special block for checking C<undef> attributes

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

One of parameters C<tnode>, C<anode>, C<nnode>, C<pnode> must be always specified.
By default: C<on_error=warn> and C<message> is empty.


=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

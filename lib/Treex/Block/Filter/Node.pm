package Treex::Block::Filter::Node;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter;

subtype 'CommaArrayRef' => as 'ArrayRef';
coerce 'CommaArrayRef'
    => from 'Str'
    => via { [split /,/] };
subtype 'CommaHashRef' => as 'HashRef[Bool]';
coerce 'CommaHashRef'
    => from 'Str'
    => via { my @a = split /,/, $_; my %hash; @hash{@a} = (1) x @a; \%hash };


requires '_build_node_types';

has 'node_types' => ( is => 'ro', isa => 'CommaArrayRef', coerce => 1, builder => '_build_node_types' );
has 'layers' => ( is => 'ro', isa => 'CommaHashRef', coerce => 1, builder => '_build_layers' );

sub _build_layers {
    my ($self) = @_;
    return "a,t";
}

sub _process_node {
    my ($self, $node, $layer) = @_;
    return if (!$self->layers->{$layer});
    my $meta = $self->meta;
    if (my $m = $meta->find_method_by_name("process_".$layer."node_filtered")) {
        return if (!Treex::Tool::Coreference::NodeFilter::matches($node, $self->node_types));
        $m->execute( $self, $node );
    }
}

sub process_anode {
    my ($self, $anode) = @_;
    $self->_process_node($anode, "a");
}

sub process_tnode {
    my ($self, $tnode) = @_;
    $self->_process_node($tnode, "t");
}


1;

__END__

=head1 NAME

Treex::Block::Filter::Node

=head1 DESCRIPTION

The role that applies process_[at]node only to the specified category of [ta]-nodes.
Whether the role is applied to a-nodes or t-nodes is specified by the parameter C<layer>.

=head1 ROLE PARAMETERS

=over

=item layer

Specifies the layer whose nodes will be processed.

=back

=head1 PARAMETERS

=over

=item node_types

A comma-separated list of the node types on which this block should be applied.
See C<Treex::Tool::Coreference::NodeFilter> for possible values.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


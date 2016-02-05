package Treex::Block::Filter::Node::A;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

use Treex::Tool::Coreference::NodeFilter;

requires 'process_filtered_anode';
requires '_build_node_types';

subtype 'CommaArrayRef' => as 'ArrayRef';
coerce 'CommaArrayRef'
    => from 'Str'
    => via { [split /,/] };

has 'node_types' => ( is => 'ro', isa => 'CommaArrayRef', coerce => 1, builder => '_build_node_types' );

sub process_anode {
    my ($self, $anode) = @_;
    return if (!Treex::Tool::Coreference::NodeFilter::matches($anode, $self->node_types));
    $self->process_filtered_anode($anode);
}

1;

__END__

=head1 NAME

Treex::Block::Filter::Node::A

=head1 DESCRIPTION

The role that applies process_anode only to the specified category of a-nodes.

=head1 PARAMETERS

=over

=item node_types

A comma-separated list of the node types on which this block should be applied.
See C<Treex::Tool::Coreference::NodeFilter> for possible values.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

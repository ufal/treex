package Treex::Block::Filter::Node;

use Moose::Util::TypeConstraints;

subtype 'CommaArrayRef' => as 'ArrayRef';
coerce 'CommaArrayRef'
    => from 'Str'
    => via { [split /,/] };
subtype 'Layer'
    => as 'Str'
    => where {m/^[at]$/i}
=> message {"Layer must be one of: [A]nalytical, [T]ectogrammatical"};

use MooseX::Role::Parameterized;

parameter layer => (
    isa => 'Layer',
    required => 1,
);

use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter;

role {

my $p = shift;
my $layer = $p->layer;

my $process_name = 'process_'.$layer.'node';
my $process_filtered_name = 'process_filtered_'.$layer.'node';

requires "$process_filtered_name";
requires '_build_node_types';

has 'node_types' => ( is => 'ro', isa => 'CommaArrayRef', coerce => 1, builder => '_build_node_types' );
#has 'layer' => ( is => 'ro', isa => 'Layer', coerce => 1, default => 't' );

method "$process_name" => sub {
    my ($self, $node) = @_;
    return if (!Treex::Tool::Coreference::NodeFilter::matches($node, $self->node_types));
    $self->$process_filtered_name($node);
};

}; # end of role {

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


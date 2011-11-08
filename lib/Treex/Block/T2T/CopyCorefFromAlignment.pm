package Treex::Block::T2T::CopyCorefFromAlignment;

use Moose;
use Treex::Core::Common;
use 5.010;    # operator //
extends 'Treex::Core::Block';

has 'type' => (
    is          => 'ro',
    isa         => enum( [qw/gram text/] ),
    required    => 1,
    default     => 'text',
);

sub _get_coref_nodes {
    my ($self, $node) = @_;

    my $method = $node->meta->find_method_by_name(
            'get_coref_'.$self->type.'_nodes');
    my @nodes = $method->execute( $node );
    return @nodes;
}

sub _add_coref_nodes {
    my ($self, $node, @antec) = @_;

    my $method = $node->meta->find_method_by_name(
            'add_coref_'.$self->type.'_nodes');
    $method->execute( $node, @antec );
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my @antec = $self->_get_coref_nodes($tnode);
    # nothing to do if no antecedent
    return if (@antec == 0);
    
    my @aligned_anaphs = @{($tnode->get_aligned_nodes)[0] // []};
    my @aligned_antec = map {@{$_ // []}} (map {($_->get_aligned_nodes)[0]} @antec);

    foreach my $source ( @aligned_anaphs ) {
        if (!defined $source) {
            print STDERR Dumper(\@aligned_anaphs);
        }
        $self->_add_coref_nodes( $source, @aligned_antec );
    }
}

1;

=head1 NAME

Treex::Block::T2T::CopyCorefFromAlignment

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

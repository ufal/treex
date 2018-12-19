package Treex::Block::A2T::SetDocOrds;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => 'Str', default => 't' );

sub process_document_one_zone_at_time {
    my ($self, $doc) = @_;
    my $last_docord = 0;
    foreach my $bundle ($doc->get_bundles) {
        my $tree = $bundle->get_tree( $self->language, $self->layer, $self->selector );

        my $node_count = 0;
        foreach my $node ($tree->get_descendants({ ordered => 1 })) {
            $node->wild->{doc_ord} = $node->ord + $last_docord;
            if ($node->ord > $node_count) {
                $node_count = $node->ord;
            }
        }
        $last_docord += $node_count;
    }
    return;
}

sub process_document {
    my ($self, $doc) = @_;
    $self->_apply_function_on_each_zone($doc, \&process_document_one_zone_at_time, $self, $doc);
    return;
}


1;

=head1 NAME

Treex::Block::A2T::SetDocOrds

=head1 DESCRIPTION

It sets the attribute C<< wild->{'doc_ord'} >>, which captures the ordinal number
of the node within the whole document. It does not reflect any later changes
in a node order or insertions and removals of nodes.

The block can be run on either the a-layer or the t-layer.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2018 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::W2A::EN::ParseMST;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::ParseMST';

use Treex::Tool::Parser::MST;

has model => (
    is      => 'rw',
    isa     => 'Str',
    default => 'conll_mcd_order2_0.01.model'
);

# All English models trained so far are projective
has '+decodetype' => ( default => 'proj' );

# English deprels do not encode is_member using $deprel =~ /_M$/
has '+detect_attributes_from_deprel' => ( default=>0);

has '+model_dir' => ( default => 'data/models/parser/mst/en' );

my %MEMORY_FOR_MODEL = (
    'conll_mcd_order2.model'      => '2600m',
    'conll_mcd_order2_0.01.model' => '750m',
    'conll_mcd_order2_0.03.model' => '540m',
    'conll_mcd_order2_0.1.model'  => '540m',
    'default'                     => '2600m',
);

# override
sub _build_memory {
    my ($self) = @_;
    return $MEMORY_FOR_MODEL{ $self->model } || $MEMORY_FOR_MODEL{default};
}

1;

__END__

=head1 NAME

Treex::Block::W2A::EN::ParseMST

=head1 DECRIPTION

MST parser (maximum spanning tree dependency parser by R. McDonald)
is used to determine the topology of a-layer trees and I<deprel> edge labels.

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

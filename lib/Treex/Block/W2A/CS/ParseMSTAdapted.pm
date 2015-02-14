package Treex::Block::W2A::CS::ParseMSTAdapted;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::ParseMST';

use Treex::Tool::Parser::MST;

has '+version'     =>  ( default => '0.4.3b-AdaptedCzech');
has '+model_dir' => ( default => 'data/models/mst_parser/cs' );
has '+model'     => ( default => 'pdt20_train_autTag_golden_latin2_pruned_0.02.model' );
has '+shorten_czech_tags' => ( default => 1 );
has '+deprel_attribute'   => ( default => 'afun' );
has '+detect_attributes_from_deprel' => ( default=>1 );

my %MEMORY_FOR_MODEL = (
    'pdt20_train_autTag_golden_latin2_pruned_0.00.model' => '1800m',
    'pdt20_train_autTag_golden_latin2_pruned_0.02.model' => '1400m',
    'pdt20_train_autTag_golden_latin2_pruned_0.10.model' => '540m',
    'pdt_zeman_train_noM_worsened_morced.model'          => '10g',
    'default'                                            => '2000m',
);

# override
sub _build_memory {
    my ($self) = @_;
    return $MEMORY_FOR_MODEL{ $self->model } || $MEMORY_FOR_MODEL{default};
}

1;

__END__

=head1 NAME

Treex::Block::W2A::CS::ParseMSTAdapted

=head1 DECRIPTION

MST parser (maximum spanning tree dependency parser by R. McDonald)
adapted by Zdenek Zabokrtsky and Vaclav Novak for Czech
is used to determine the topology of a-layer trees and I<deprel> edge labels.

=head1 SEE ALSO

L<Treex::Block::W2A::ParseMST>

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


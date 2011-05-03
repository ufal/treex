package Treex::Block::W2A::EN::ParseMST;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tools::Parser::MST;

has 'model' => ( is => 'rw', isa => 'Str', default => 'conll_mcd_order2_0.01.model' );
my $parser;

#TODO: loading each model only once should be handled in different way

sub BUILD {
    my ($self) = @_;

    my %model_memory_consumption = (
        'conll_mcd_order2.model'      => '2600m',    # tested on sol1, sol2 (64bit)
        'conll_mcd_order2_0.01.model' => '750m',     # tested on sol2 (64bit) , cygwin (32bit win), java-1.6.0(64bit)
        'conll_mcd_order2_0.03.model' => '540m',     # load block tested on cygwin notebook (32bit win), java-1.6.0(64bit)
        'conll_mcd_order2_0.1.model'  => '540m',     # load block tested on cygwin notebook (32bit win), java-1.6.0(64bit)
    );

    my $DEFAULT_MODEL_MEMORY = '2600m';
    my $model_dir            = "$ENV{TMT_ROOT}/share/data/models/mst_parser/en";

    my $model_memory = $model_memory_consumption{ $self->model } || $DEFAULT_MODEL_MEMORY;

    my $model_path = $model_dir . '/' . $self->model;

    if ( !$parser ) {
        $parser = Treex::Tools::Parser::MST->new(
            {   model      => $model_path,
                memory     => $model_memory,
                order      => 2,
                decodetype => 'proj'
            }
        );
    }
    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # We deliberately approximate e.g. curly quotes with plain ones
    my @words = map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) } @a_nodes;
    my @tags  = map { $_->tag } @a_nodes;

    my ( $parents_rf, $deprel_rf, $matrix_rf ) = $parser->parse_sentence( \@words, \@tags );

    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $deprel = shift @$deprel_rf;
        $a_node->set_conll_deprel($deprel);

        if ($matrix_rf) {
            my $scores = shift @$matrix_rf;
            if ($scores) {
                $a_node->set_attr( 'mst_scores', join( ' ', @$scores ) );
            }
        }

        my $parent_index = shift @$parents_rf;
        if ($parent_index) {
            my $parent = $a_nodes[ $parent_index - 1 ];
            $a_node->set_parent($parent);
        }
        else {
            push @roots, $a_node;
        }
    }
    return @roots;
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

=head1 COPYRIGHT

Copyright 2011 Martin Popel, David Mareček
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::W2A::ParseMST;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::MST;

has 'model' => ( is => 'rw', isa => 'Str', required => 1 );
has 'order' => ( is => 'rw', isa => 'Str', default => '2' );
has 'decodetype' => ( is => 'rw', isa => 'Str', default => 'non-proj' );
has 'pos_attribute' => ( is => 'rw', isa => 'Str', default => 'tag' );
has 'deprel_attribute' => ( is => 'rw', isa => 'Str', default => 'conll/deprel' );
has robust => (is=> 'ro', isa=>'Bool', default=>0, documentation=>'try to recover from MST failures by paring 2 more times and returning flat tree at least' );
has _parser => (is=>'rw');
my %loaded_models;


#my $parser;

#TODO: loading each model only once should be handled in different way
# !!! copied from EN::ParseMST

sub BUILD {
    my ($self) = @_;

    my %model_memory_consumption = (
        'conll_mcd_order2.model'      => '2600m',    # tested on sol1, sol2 (64bit)
        'conll_mcd_order2_0.01.model' => '750m',     # tested on sol2 (64bit) , cygwin (32bit win), java-1.6.0(64bit)
        'conll_mcd_order2_0.03.model' => '540m',     # load block tested on cygwin notebook (32bit win), java-1.6.0(64bit)
        'conll_mcd_order2_0.1.model'  => '540m',     # load block tested on cygwin notebook (32bit win), java-1.6.0(64bit)
    );

    my $DEFAULT_MODEL_MEMORY = '4000m';
    my $model_dir            = "$ENV{TMT_ROOT}/share/data/models/mst_parser/en";
   
    my $model_memory = $model_memory_consumption{ $self->model } || $DEFAULT_MODEL_MEMORY;
   
    my $model_path = $model_dir . '/' . $self->model;
    
    if (!$loaded_models{$model_path}){
       my $parser = Treex::Tool::Parser::MST->new(
       {   	model      => $model_path,
                memory     => $model_memory,
                order      => $self->order,
                decodetype => $self->decodetype,
                robust     => $self->robust,
            }
            
            );
	    $loaded_models{$model_path} = $parser;
}
$self->_set_parser($loaded_models{$model_path});

    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # We deliberately approximate e.g. curly quotes with plain ones
    my @words = map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) } @a_nodes;
    my @tags  = map { $_->get_attr($self->pos_attribute) } @a_nodes;

    my ( $parents_rf, $deprel_rf, $matrix_rf ) = $self->_parser->parse_sentence( \@words, \@tags );

    my @roots = ();
    foreach my $a_node (@a_nodes) {
        $a_node->set_is_member(0);
        $a_node->set_is_shared_modifier(0);
        my $deprel = shift @$deprel_rf;
        if ($deprel =~ /_(M?S?C?)$/) {
            my $suffix = $1;
            $a_node->set_is_member($suffix =~ /M/ ? 1 : 0);
            $a_node->set_is_shared_modifier($suffix =~ /S/ ? 1 : 0);
            $a_node->wild->{is_coord_conjunction} = $suffix =~ /C/ ? 1 : 0;
            $deprel =~ s/_M?S?C?$//;
        }
        $a_node->set_attr($self->deprel_attribute, $deprel);

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

Treex::Block::W2A::ParseMST

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

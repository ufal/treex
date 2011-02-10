package Treex::Block::W2A::EN::ParseMST;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );
has 'model'   => ( is => 'rw', isa => 'Str',  default => 'conll_mcd_order2_0.01.model' );
has 'reparse' => ( is => 'rw', isa => 'Bool', default => 0 );
has '_parser' => ( is => 'rw' );

# TODO (MP): refactor parentheses chunks
# Segmentation to chunks with parentheses (and possibly also direct speeches)
# should be moved from this block to another to keep it modular and flexible.
# Chunk segmentation should be saved in some attributes (schema update needed).
# The goal of segmenting a sentence into chunks is to guarantee that each chunk
# will be parsed into its own subtree.

use DowngradeUTF8forISO2;
use Treex::Tools::Parser::MST;

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

    #my $model_name = $ENV{TMT_PARAM_MCD_EN_MODEL};
    #if ( !defined $model_name ) {
    #    $model_name = $DEFAULT_MODEL_NAME;
    #    Report::info("Variable TMT_PARAM_MCD_EN_MODEL not set, using $model_name");
    #}

    my $model_memory = $model_memory_consumption{ $self->model } || $DEFAULT_MODEL_MEMORY;

    my $model_path = $model_dir . "/" . $self->model;

    if ( !$self->_parser ) {
        $self->_set_parser(
            Treex::Tools::Parser::MST->new(
                {   model      => $model_path,
                    memory     => $model_memory,
                    order      => 1,
                    decodetype => 'proj'
                }
                )
        );
    }

}

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );

    # Skip the sentence if this block is used in "reparse" mode and no reparsing is needed
    return 1 if $self->reparse && !$a_root->get_attr('reparse');

    # Delete old topology (so no cycles will be introduced during the parsing)
    foreach my $a_node (@a_nodes) {
        $a_node->set_parent($a_root);
    }

    # Segment the sentence into chunks according to parentheses
    my @chunks = find_parenthesis_chunks( $a_root, @a_nodes );

    # Parse each chunk with McDonald's parser
    # and hang the chunk to its parent (currently it is the preceding word).
    foreach my $chunk (@chunks) {
        my @chunk_nodes  = @{ $chunk->{nodes} };
        my $chunk_parent = $chunk->{parent};
        my ( $lrb, $rrb );

        # If this is parenthesis chunk, cut off left and right parentheses
        if ( $chunk_parent != $a_root ) {
            $lrb = shift @chunk_nodes;
            $rrb = pop @chunk_nodes;
        }

        # Here comes the very parsing.
        # Hopefully, the chunk has got just one root, but rather check it.
        my ( $first_chunk_root, @other_chunk_roots ) = $self->parse_chunk(@chunk_nodes);
        $first_chunk_root->set_parent($chunk_parent);
        foreach my $other_chunk_root (@other_chunk_roots) {
            $other_chunk_root->set_parent($first_chunk_root);
        }

        # Try hard to hang both parentheses on the root of the chunk.
        # (Parser would mostly guess this right, but not always.)
        if ( $chunk_parent != $a_root ) {
            foreach my $bracket ( $lrb, $rrb ) {
                $bracket->set_attr( 'conll_deprel', 'P' );
                $bracket->set_parent($first_chunk_root);
            }
        }
    }
    return 1;
}

sub find_parenthesis_chunks {
    my ( $a_root, @a_nodes ) = @_;
    my ( @chunks, @chunk_nodes, @base_nodes );
    my $in_paren = 0;
    my $parent   = $a_root;

    foreach my $a_node (@a_nodes) {
        my $form = $a_node->form;
        if ( $form eq '(' ) {
            return { nodes => \@a_nodes, parent => $a_root } if $in_paren;
            $in_paren = 1;
            push @chunk_nodes, $a_node;
        }
        elsif ( $form eq ')' ) {

            # abort if single parenthesis or empty pair "( )"
            return { nodes => \@a_nodes, parent => $a_root }
                if !$in_paren || 1 == scalar @chunk_nodes;
            push @chunk_nodes, $a_node;
            push @chunks, { nodes => [@chunk_nodes], parent => $parent };
            @chunk_nodes = ();
            $in_paren    = 0;
        }
        elsif ($in_paren) {
            push @chunk_nodes, $a_node;
        }
        else {
            push @base_nodes, $a_node;
            $parent = $a_node;
        }
    }

    # If there is an unfinished parenthesis chunk, return all in one chunk
    return { nodes => \@a_nodes, parent => $a_root } if @chunk_nodes;

    # Add all nodes that were not in parentheses as a first chunk.
    # (This is not needed when the whole sentence is in parenthesis.)
    if (@base_nodes) {
        unshift @chunks, { nodes => \@base_nodes, parent => $a_root };
    }
    return @chunks;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # We deliberately approximate e.g. curly quotes with plain ones
    my @words = map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) } @a_nodes;
    my @tags  = map { $_->tag } @a_nodes;

    my ( $parents_rf, $deprel_rf, $matrix_rf ) = $self->_parser->parse_sentence( \@words, \@tags );

    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $deprel = shift @$deprel_rf;
        $a_node->set_conll_deprel($deprel);

        if ($matrix_rf) {
            my $scores = shift @$matrix_rf;
            $a_node->set_attr( 'mst_scores', join( " ", @$scores ) ) if $scores;
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

#TODO Try separating also quotes that form a sentence (or final clause).

__END__
 
=over

=item Treex::Block::W2A::EN::ParseMST

SEnglishA tree is created within each bundle and McDonald's parser is used for
determining its topology.

This block preprocess the sentence by segmenting it into chunks according to
the parentheses. Each chunk is then parsed separately which improves the performance. 

Specify the model by setting the environment
variable TMT_PARAM_MCD_EN_MODEL to the model file name (not the whole path). If undefined,
the file conll_mcd_order2_0.01.model is used and a warning is issued.

PARAMETERS:
REPARSE - process only bundles where SEnglishA root-node has the attribute C<reparse> set 

=back

=cut

# Copyright 2008-2011 Vaclav Novak, Martin Popel, David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

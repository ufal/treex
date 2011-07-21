package Treex::Block::W2A::BaseChunkParser;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'reparse' => ( is => 'rw', isa => 'Bool', default => 0 );

sub process_atree {
    my ( $self, $a_root ) = @_;
    my @a_nodes = $a_root->get_descendants( { ordered => 1 } );

    # Skip the sentence if this block is used in "reparse" mode and no reparsing is needed
    return 1 if $self->reparse && !$a_root->get_attr('reparse');

    # Delete old topology (so no cycles will be introduced during the parsing)
    foreach my $a_node (@a_nodes) {
        $a_node->set_parent($a_root);
    }

    # Get chunks
    my %chunks;
    foreach my $a_node (@a_nodes) {
        my $anode_chunks_ref = $a_node->get_attr('chunks') or next;
        foreach my $name (@$anode_chunks_ref) {
            push @{ $chunks{$name} }, $a_node;
        }
    }

    # Sort the chunks from the shortest to the longest one,
    # delete possible full-sentence chunks
    my @sorted_chunks = sort { @$a <=> @$b } grep { @$_ < @a_nodes } values %chunks;

    # Parse each chunk independently (plus the whole sentence)
    foreach my $chunk ( @sorted_chunks, \@a_nodes ) {

        # There can be a nested chunk inside $chunk,
        # which is shorter and therefore already parsed.
        # We skip all the nodes of the nested chunk except for its root
        # which was left attached to the $a_root.
        my @ch_nodes = grep { $_->parent == $a_root } @$chunk;
        
        # If this is a "parenthesis chunk" (enclosed in round brackets),
        # leave the brackets aside to be hanged on the root of the chunk later.
        # (Parsers would mostly guess this right, but not always.)        
        my ( $lrb, $rrb ) = @ch_nodes[ 0, -1 ];
        if ( $lrb->form eq '(' && $rrb->form eq ')' ) {
            shift @ch_nodes;
            pop @ch_nodes;
        } else {
            $lrb = undef;
        }

        # Here comes the very parsing.
        # Hopefully, the chunk has got just one root, but rather check it.
        my ( $ch_root, @other_ch_roots ) = $self->parse_chunk(@ch_nodes);
        foreach my $another_ch_root (@other_ch_roots) {
            $another_ch_root->set_parent($ch_root);
        }

        # If this is "parenthesis chunk" (enclosed in round brackets)
        if ($lrb) {

            # Hang both of the brackets on the root of the chunk.
            foreach my $bracket ( $lrb, $rrb ) {
                $bracket->set_parent($ch_root);
                $self->label_parenthesis_token($bracket);
            }

            # We can guess the parent of this chunk (usually the previous word)
            $ch_root->set_parent( $lrb->get_prev_node || $rrb->get_next_node || $a_root );
        }
    }
    return;
}

sub label_parenthesis_token {
    my ($self, $anode) = @_;
    $anode->set_conll_deprel('P');
    $anode->set_afun('AuxG');
    return;
}

sub parse_chunk {
    log_fatal 'parse_chunk must be implemented in derived clases';
    my ( $self, @a_nodes ) = @_;
}

1;

__END__
 
=over

=item Treex::Block::W2A::BaseChunkParser

This class serves as a base class for dependency parsers
that just need to override the C<parse_chunk> method.

The goal of segmenting a sentence into chunks is to guarantee that each chunk
will be parsed into its own subtree.

PARAMETERS:
reparse - process only bundles where the root node has the attribute C<reparse> set 

=back

=head1 METHODS

=over

=item label_parenthesis_token

Set the edge label of a parenthesis (round bracket) token.
This implementation sets C<conll_deprel> attribute to I<P>
and C<afun> to I<AuxG>,
but the method can be overriden if needed to set.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

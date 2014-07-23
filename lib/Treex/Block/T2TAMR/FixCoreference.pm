package Treex::Block::T2TAMR::FixCoreference;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has '+selector' => ( isa => 'Str', default => 'amrConvertedFromT' );

# find the AMR variable of the coreferred node
sub _get_coref_varname {
    my ( $self, $src_coref_node ) = @_;
    my ($tgt_coref_node) = $src_coref_node->get_referencing_nodes('src_tnode.rf');
    my ($var_name) = split( '/', $tgt_coref_node->t_lemma );
    return $var_name;
}

# only return the 1st node in a coref chain + never go across the sentence boundary
# (return undefs instead)
sub _filter_coref_node {
    my ( $self, $tnode, $tantec ) = @_;
    return first { $_->get_root == $tnode->get_root } $tantec->get_coref_chain( { add_self => 1, ordered => 1 } );
}

sub process_tnode {

    my ( $self, $tnode ) = @_;

    my $src_tnode = $tnode->src_tnode;
    # this can happen for e.g. the generated polarity node
    return if !defined $src_tnode;

    # look for coreference links, filter out any that do not end in the same sentence
    my @coref_nodes = grep { defined $_ }
        map { $self->_filter_coref_node( $src_tnode, $_ ); } $src_tnode->get_coref_nodes();

    if (@coref_nodes) {
        # forward the filtered coreference links to the new AMR nodes
        my @new_coref_nodes = map { $_->get_referencing_nodes('src_tnode.rf') } @coref_nodes;
        if (@new_coref_nodes){
            $tnode->set_deref_attr( 'coref_text.rf', \@new_coref_nodes );
    
            # update lemmas for #Cor/#PersPron
            if ( $src_tnode->t_lemma =~ /#(Cor|PersPron)/ ) {
                $tnode->set_t_lemma( $self->_get_coref_varname($coref_nodes[0]) );
            }
        }
    }

    return;
}

1;

=over

=item Treex::Block::T2TAMR::FixCoreference

=back

=cut

# Copyright 2014

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

package Treex::Block::T2TAMR::FixCoreference;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has '+selector'       => ( isa => 'Str', default => 'amrConvertedFromT' );


sub process_tnode {
    
    my ( $self, $tnode ) = @_;

    my $src_tnode = $tnode->src_tnode;
    # can happen for e.g. the generated polarity node
    return if !defined $src_tnode;

    my $coref_gram = $src_tnode->get_deref_attr('coref_gram.rf');
    my $coref_text = $src_tnode->get_deref_attr('coref_text.rf');
    my @nodelist   = (); # new coreference links go here
    
    # look for coreference links and convert them
    if ( defined $coref_gram ) {
        push @nodelist, map { $_->get_referencing_nodes('src_tnode.rf') } @$coref_gram;

        # changing #Cor to appropriate param
        if ( $src_tnode->t_lemma eq '#Cor') {
            my $src_coref_gram_node = shift @$coref_gram;
            if ($src_coref_gram_node->get_root eq $src_tnode->get_root){
              my ($tgt_coref_gram_node) = $src_coref_gram_node->get_referencing_nodes('src_tnode.rf');
              my ($new_src_tlemma) = split( '/', $tgt_coref_gram_node->t_lemma );
              #print STDERR "$new_src_tlemma\n";

              #print STDERR "$tnode\n";
              $tnode->set_attr( 't_lemma', $new_src_tlemma );
          }
        }
    }

    if ( defined $coref_text ) {
        push @nodelist, map { $_->get_referencing_nodes('src_tnode.rf') } @$coref_text;
        if ( $src_tnode->t_lemma eq '#PersPron' ) {
            my $src_coref_text_node = shift @$coref_text;
            if ($src_coref_gram_node->get_root eq $src_tnode->get_root){
              my ($tgt_coref_text_node) = $src_coref_text_node->get_referencing_nodes('src_tnode.rf');
              my ($new_src_tlemma) = split( '/', $tgt_coref_text_node->t_lemma );
              
              #print STDERR "$new_src_tlemma\n";
              $tnode->set_attr( 't_lemma', $new_src_tlemma );
            }
        }
    }
    
    # if we've found some coreference links, store them    
    $tnode->set_deref_attr( 'coref_text.rf', \@nodelist ) if 0 < scalar(@nodelist);

    return;
}

1;

=over

=item Treex::Block::T2TAMR::FixCoreference

=back

=cut

# Copyright 2014

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

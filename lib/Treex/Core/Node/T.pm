package Treex::Core::Node::T;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';
with 'Treex::Core::Node::Ordered';
with 'Treex::Core::Node::InClause';
with 'Treex::Core::Node::EffectiveRelations';

# t-layer attributes
has [
    qw( nodetype t_lemma functor subfunctor formeme tfa
        is_dsp_root sentmod is_parenthesis is_passive is_generated
        is_relclause_head is_name_of_person voice
        t_lemma_origin formeme_origin
        )
] => ( is => 'rw' );

sub get_pml_type_name {
    my ($self) = @_;
    return $self->is_root() ? 't-root.type' : 't-node.type';
}

# the node is a root of a coordination/apposition construction
# analogy of PML_T::IsCoord
sub is_coap_root {
    my ($self) = @_;
    log_fatal("Incorrect number of arguments") if @_ != 1;
    return ( $self->functor || '' ) =~ /^(CONJ|CONFR|DISJ|GRAD|ADVS|CSQ|REAS|CONTRA|APPS|OPER)$/;
}

#----------- a-layer (analytical) nodes -------------

sub get_lex_anode {
    my ($self)   = @_;
    my $lex_rf   = $self->get_attr('a/lex.rf');
    my $document = $self->get_document();
    return $document->get_node_by_id($lex_rf) if $lex_rf;
    return;
}

sub set_lex_anode {
    my ( $self, $lex_anode ) = @_;
    my $new_id = defined $lex_anode ? $lex_anode->get_attr('id') : undef;
    $self->set_attr( 'a/lex.rf', $new_id );
    return;
}

sub get_aux_anodes {
    my ( $self, $arg_ref ) = @_;
    ##my @nodes  = $self->get_r_attr('a/aux.rf');
    my $doc    = $self->get_document();
    my $aux_rf = $self->get_attr('a/aux.rf');
    my @nodes  = $aux_rf ? ( map { $doc->get_node_by_id($_) } @{$aux_rf} ) : ();
    return @nodes if !$arg_ref;
    log_fatal('Switches preceding_only and following_only cannot be used with get_aux_anodes (t-nodes vs. a-nodes).')
        if $arg_ref->{preceding_only} || $arg_ref->{following_only};
    return $self->_process_switches( $arg_ref, @nodes );
}

sub set_aux_anodes {
    my $self       = shift;
    my @aux_anodes = @_;
    $self->set_attr( 'a/aux.rf', [ map { $_->get_attr('id') } @aux_anodes ] );
    return;
}

sub add_aux_anodes {
    my $self = shift;
    my @prev = $self->get_aux_anodes();
    $self->set_aux_anodes( @prev, @_ );
    return;
}

sub get_anodes {
    my ( $self, $arg_ref ) = @_;
    my $lex_anode = $self->get_lex_anode();
    my @nodes = ( ( defined $lex_anode ? ($lex_anode) : () ), $self->get_aux_anodes() );
    return @nodes if !$arg_ref;
    log_fatal('Switches preceding_only and following_only cannot be used with get_anodes (t-nodes vs. a-nodes).')
        if $arg_ref->{preceding_only} || $arg_ref->{following_only};
    return $self->_process_switches( $arg_ref, @nodes );
}

#----------- n-layer (named entity) nodes -------------

sub get_n_node {
    my ($self) = @_;
    my $lex_anode = $self->get_lex_anode() or return;
    return $lex_anode->n_node();
}

#----------- source t-layer (source-language in MT) nodes -------------

sub src_tnode {
    my ($self) = @_;
    my $source_node_id = $self->get_attr('src_tnode.rf') or return;
    return $self->get_document->get_node_by_id($source_node_id);
}

sub set_src_tnode {
    my ( $self, $source_node ) = @_;
    $self->set_attr( 'src_tnode.rf', $source_node->id );
    return;
}

#----------- grammatemes -------------

#TODO: make these real Moose attributes
sub gram_sempos        { return $_[0]->get_attr('gram/sempos'); }
sub gram_gender        { return $_[0]->get_attr('gram/gender'); }
sub gram_number        { return $_[0]->get_attr('gram/number'); }
sub gram_degcmp        { return $_[0]->get_attr('gram/degcmp'); }
sub gram_verbmod       { return $_[0]->get_attr('gram/verbmod'); }
sub gram_deontmod      { return $_[0]->get_attr('gram/deontmod'); }
sub gram_tense         { return $_[0]->get_attr('gram/tense'); }
sub gram_aspect        { return $_[0]->get_attr('gram/aspect'); }
sub gram_resultative   { return $_[0]->get_attr('gram/resultative'); }
sub gram_dispmod       { return $_[0]->get_attr('gram/dispmod'); }
sub gram_iterativeness { return $_[0]->get_attr('gram/iterativeness'); }
sub gram_indeftype     { return $_[0]->get_attr('gram/indeftype'); }
sub gram_person        { return $_[0]->get_attr('gram/person'); }
sub gram_numertype     { return $_[0]->get_attr('gram/numertype'); }
sub gram_politeness    { return $_[0]->get_attr('gram/politeness'); }
sub gram_negation      { return $_[0]->get_attr('gram/negation'); }
sub gram_definiteness  { return $_[0]->get_attr('gram/definiteness'); }

sub set_gram_sempos        { return $_[0]->set_attr( 'gram/sempos',        $_[1] ); }
sub set_gram_gender        { return $_[0]->set_attr( 'gram/gender',        $_[1] ); }
sub set_gram_number        { return $_[0]->set_attr( 'gram/number',        $_[1] ); }
sub set_gram_degcmp        { return $_[0]->set_attr( 'gram/degcmp',        $_[1] ); }
sub set_gram_verbmod       { return $_[0]->set_attr( 'gram/verbmod',       $_[1] ); }
sub set_gram_deontmod      { return $_[0]->set_attr( 'gram/deontmod',      $_[1] ); }
sub set_gram_tense         { return $_[0]->set_attr( 'gram/tense',         $_[1] ); }
sub set_gram_aspect        { return $_[0]->set_attr( 'gram/aspect',        $_[1] ); }
sub set_gram_resultative   { return $_[0]->set_attr( 'gram/resultative',   $_[1] ); }
sub set_gram_dispmod       { return $_[0]->set_attr( 'gram/dispmod',       $_[1] ); }
sub set_gram_iterativeness { return $_[0]->set_attr( 'gram/iterativeness', $_[1] ); }
sub set_gram_indeftype     { return $_[0]->set_attr( 'gram/indeftype',     $_[1] ); }
sub set_gram_person        { return $_[0]->set_attr( 'gram/person',        $_[1] ); }
sub set_gram_numertype     { return $_[0]->set_attr( 'gram/numertype',     $_[1] ); }
sub set_gram_politeness    { return $_[0]->set_attr( 'gram/politeness',    $_[1] ); }
sub set_gram_negation      { return $_[0]->set_attr( 'gram/negation',      $_[1] ); }
sub set_gram_definiteness  { return $_[0]->set_attr( 'gram/definiteness',  $_[1] ); }

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Node::T

=head1 DESCRIPTION

t-layer (tectogrammatical) node


=head1 METHODS

=head2 Access to a-layer (analytical nodes)

=over

=item $node->add_aux_anodes(@aux_anodes)

Add auxiliary a-nodes (to C<a/aux.rf>)

=item $anodes = $node->get_anodes()

Return a-nodes (both auxiliary and lexical, ie. C<a/aux.rf> and C<a/lex.rf>)

=item @aux_anodes = $node->get_aux_anodes()

Return auxiliary a-nodes (from C<a/aux.rf>).

=item $lex_anod = $node->get_lex_anode()

Return the lexical a-nodes (from C<a/lex.rf>).

=item $node->set_aux_anodes(@aux_anodes)

Set the auxiliary a-nodes (to C<a/aux.rf>).

=item set_lex_anode

Set the lexical a-node (to C<a/lex.rf>).

=back

=head2 Access to source language t-layer (in MT)

=over

=item $src_tnode = $node->src_tnode()

Return the source language (in MT) t-node (from C<src_tnode.rf>).

=item set_src_tnode

Set the source language (in MT) t-node (to C<src_tnode.rf>).

=back

=head2 Access to n-layer (named entity nodes)

Note there is no C<set_n_node> method.
You must set the link from n-node to a a-node.

=over

=item $node->get_n_node()

This is a shortcut for C<< $self->get_lex_anode()->n_node; >>
If this t-node is a part of a named entity,
this method returns the corresponding n-node (L<Treex::Core::Node::N>).
If this node is a part of more than one named entities,
only the most nested one is returned.
For example: "Bank of China"

 $n_node_for_china = $t_node_china->get_n_node();
 print $n_node_for_china->get_attr('normalized_name'); # China
 $n_node_for_bank_of_china = $n_node_for_china->get_parent();
 print $n_node_for_bank_of_china->get_attr('normalized_name'); # Bank of China


=back

=head2 Other methods

=over

=item is_coap_root

Is this node a root (or head) of a coordination/apposition construction?
On t-layer this is decided based on C<functor =~ /^(CONJ|CONFR|DISJ|GRAD|ADVS|CSQ|REAS|CONTRA|APPS|OPER)/>.

=back 


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

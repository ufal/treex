package Treex::Core::Node::T;

use namespace::autoclean;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';
with 'Treex::Core::Node::Ordered';
with 'Treex::Core::Node::InClause';
with 'Treex::Core::Node::EffectiveRelations';
with 'Treex::Core::Node::Interset' => { interset_attribute => 'dset' };

# t-layer attributes
has [
    qw( nodetype t_lemma functor subfunctor formeme tfa
        is_dsp_root sentmod is_parenthesis is_passive is_generated
        is_relclause_head is_name_of_person voice
        t_lemma_origin formeme_origin is_infin
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

#----------- helpers for reference lists ------------

sub _get_node_list {
    my ( $self, $list, $arg_ref ) = @_;
    $list = $self->get_attr($list);
    my $doc = $self->get_document();
    my @nodes = $list ? ( map { $doc->get_node_by_id($_) } @{$list} ) : ();
    return $arg_ref ? $self->_process_switches( $arg_ref, @nodes ) : @nodes;
}

sub _set_node_list {
    my $self = shift;
    my $list = shift;
    $self->set_attr( $list, [ map { $_->get_attr('id') } @_ ] );
    return;
}

sub _add_to_node_list {
    my $self = shift;
    my $list = shift;

    # get the current elements of the list
    my $cur_ref = $self->get_attr($list);
    my @cur = $cur_ref ? @{$cur_ref} : ();

    # grep only those that aren't already in the list
    my @new = grep {
        my $id = $_;
        !any { $_ eq $id } @cur
    } map { $_->get_attr('id') } @_;

    # set the new list value
    $self->set_attr( $list, [ @cur, @new ] );
    return;
}

sub _remove_from_node_list {
    my $self = shift;
    my $list = shift;
    my @prev = $self->_get_node_list($list);
    my @remain;

    foreach my $node (@prev) {
        if ( !grep { $_ == $node } @_ ) {
            push @remain, $node;
        }
    }
    $self->_set_node_list( $list, @remain );
    return;
}

# TODO: with backrefs this method is no more needed
# remove unindexed IDs from a list attribute
sub _update_list {

    my ( $self, $list ) = @_;
    my $doc = $self->get_document();

    my $ref = $self->get_attr($list);
    my (@nodes, @invalid);

    return if (!$ref);

    foreach my $id (@{$ref}){
        if ($doc->id_is_indexed($id)){
            push @nodes, $id;
        }
        else {
            push @invalid, $id;
        }
    }

    $self->set_attr( $list, @nodes > 0 ? [@nodes] : undef );
    return;
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

    log_fatal('Switches preceding_only and following_only cannot be used with get_aux_anodes (t-nodes vs. a-nodes).')
        if $arg_ref and ( $arg_ref->{preceding_only} or $arg_ref->{following_only} );

    return $self->_get_node_list( 'a/aux.rf', $arg_ref );
}

sub set_aux_anodes {
    my $self = shift;
    return $self->_set_node_list( 'a/aux.rf', @_ );
}

sub add_aux_anodes {
    my $self = shift;
    return $self->_add_to_node_list( 'a/aux.rf', @_ );
}

sub remove_aux_anodes {
    my $self = shift;
    return $self->_remove_from_node_list( 'a/aux.rf', @_ );
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

#------------ coreference and bridging nodes -------------------

sub get_appos_expansion {
    my ($self, $arg_ref ) = @_;
    if ($self->is_coap_root && $self->functor eq "APPS") {
        return ($self->get_coap_members({direct_only => 1}), $arg_ref->{with_appos_root} ? $self : ());
    }
    else {
        my $par = $self->get_parent;
        if (defined $par && !$par->is_root && $par->is_coap_root && $par->functor eq "APPS" && $self->is_member ) {
            return ($par->get_coap_members({direct_only => 1}), $arg_ref->{with_appos_root} ? $par : ());
        }
    }
    return $self;
}

# types are not allowed for the time being
sub _unfold_appos {
    my ( $self, $type ) = @_;

    my @appos_nodes_not_self = grep {$_ != $self} $self->get_appos_expansion({with_appos_root => 1});
    
    my @member_antes = ();
    # type = { text, gram, all }
    if ($type eq "gram") {
        @member_antes = map {$_->get_coref_gram_nodes({appos_aware => 0})} @appos_nodes_not_self;
    }
    elsif ($type eq "text") {
        @member_antes = map {$_->get_coref_text_nodes({appos_aware => 0})} @appos_nodes_not_self;
    }
    else {
        @member_antes = map {$_->get_coref_nodes({appos_aware => 0})} @appos_nodes_not_self;
    }
    return @member_antes;
}

sub _replace_appos_antes {
    my (@antes) = @_;
    my @new_antes = map {$_->get_appos_expansion({with_appos_root => 0})} @antes;
    my %seen = ();
    my @unique_antes = grep { !$seen{$_->id}++ } @new_antes;
    return @unique_antes; 
}

sub _get_coref_nodes {
    my ($self, $type, $arg_ref) = @_;

    my $appos_aware = $arg_ref->{appos_aware} // 1;
    my $with_types = $arg_ref->{with_types} // 0;
    delete $arg_ref->{$_} foreach (qw/appos_aware with_types/);

    my @antes = ();
    my @types = ();

    if ($type ne 'text') {
        my @gram_nodes = $self->_get_node_list('coref_gram.rf');
        push @antes, @gram_nodes; 
        push @types, map {undef} @gram_nodes;
    }
    if ($type ne 'gram') {
        # textual coreference in PDT2.0 and 2.5 style
        my @text_nodes = $self->_get_node_list('coref_text.rf');
        push @antes, @text_nodes; 
        push @types, map {undef} @text_nodes;
        # textual coreference in PDT3.0 style
        my $pdt30_text_coref_rf = $self->get_attr('coref_text') // [];
        @text_nodes = map {$self->get_document->get_node_by_id( $_->{'target_node.rf'} )} @$pdt30_text_coref_rf;
        my @text_types = map { $_->{'type'} } @$pdt30_text_coref_rf;
        push @antes, @text_nodes; 
        push @types, @text_types;
    }

    # for the time being, apposition-aware handling is disabled if types are demanded
    if (!$with_types && $appos_aware) {
        push @antes, $self->_unfold_appos($type);
        @antes = _replace_appos_antes(@antes);
    }
    
    my @filtered_antes = $self->_process_switches( $arg_ref, @antes );
    return @filtered_antes if (!$with_types);

    # return both nodes and types (as list references - similar to alignments)
    my %node_id_to_index = map {$antes[$_]->id => $_} 0 .. $#antes;
    my @filtered_types = map {
        my $idx = $node_id_to_index{$_->id};
        defined $idx ? $types[$idx] : undef
    } @filtered_antes;
    return (\@filtered_antes, \@filtered_types);
}


sub get_coref_nodes {
    my ( $self, $arg_ref ) = @_;
    return $self->_get_coref_nodes('all', $arg_ref);
}

sub get_coref_gram_nodes {
    my ( $self, $arg_ref ) = @_;
    return $self->_get_coref_nodes('gram', $arg_ref);
}

sub get_coref_text_nodes {
    my ( $self, $arg_ref ) = @_;
    return $self->_get_coref_nodes('text', $arg_ref);
}


# it doesn't return a complete chain, just the members which are accessible
# from the current node
# TODO: with backrefs the whole chain is accessible now
sub get_coref_chain {
    my ( $self, $arg_ref ) = @_;

    my %visited_nodes = ();
    my @nodes;
    my %sub_args = map {$_ => $arg_ref->{$_}} qw/appos_aware with_types/;
    my @queue = $self->get_coref_nodes(\%sub_args);
    while ( my $node = shift @queue ) {
        $visited_nodes{$node} = 1;
        push @nodes, $node;
        my @antes = $node->get_coref_nodes(\%sub_args);
        foreach my $ante (@antes) {
            if ( !defined $visited_nodes{$ante} ) {
                push @queue, $ante;
            }
        }
    }

    return $self->_process_switches( $arg_ref, @nodes );
}

sub select_node_if_apps {
    my ($node) = @_;
    my $par = $node->get_parent;
    if (defined $par && !$par->is_root && $par->is_coap_root && $par->functor eq "APPS" && $node->is_member ) {
        return $par;
    }
    return $node;
}

sub _add_coref_nodes {
    my ($self, $type, @antes) = @_;
    
    # if called on a member of an apposition, call it on the apposition root
    my $anaph = select_node_if_apps($self);
    if ($anaph != $self) {
        return $anaph->_add_coref_nodes($type, @antes);
    }

    # antes must be apposition roots if in apposition
    @antes = map {select_node_if_apps($_)} @antes;
    
    # avoid link repeating and self-reference
    my %seen;
    @antes = grep {$_ != $self} grep {!$seen{$_->id}++} @antes;
    return if (!@antes); 
    
    $self->_add_to_node_list( "coref_$type.rf", @antes );
}

sub add_coref_gram_nodes {
    my $self = shift;
    $self->_add_coref_nodes('gram', @_);
}

sub add_coref_text_nodes {
    my $self = shift;
    $self->_add_coref_nodes('text', @_);
}

sub remove_coref_nodes {
    my $self = shift;
    $self->_remove_from_node_list( 'coref_gram.rf', @_ );
    $self->_remove_from_node_list( 'coref_text.rf', @_ );
    return;
}

# remove unindexed IDs from coreference lists
sub update_coref_nodes {
    my $self = shift;

    $self->_update_list('coref_gram.rf');
    $self->_update_list('coref_text.rf');
    return;
}

sub get_bridging_nodes {
    my ($self, $arg_ref) = @_;
    my $bridging = $self->get_attr('bridging') // [];
    my $doc = $self->get_document;
    my @nodes = map {$doc->get_node_by_id($_->{'target_node.rf'})} @$bridging; 
    my @types = map {$_->{'type'}} @$bridging;
    return (\@nodes, \@types);
}

sub add_bridging_node {
    my ( $self, $node, $type ) = @_;
    my $links_rf = $self->get_attr('bridging');
    my %new_link = ( 'target_node.rf' => $node->id, 'type' => $type // ''); #/ so we have no undefs
    push( @$links_rf, \%new_link );
    $self->set_attr( 'bridging', $links_rf );
    return;
}

# ----------- complement nodes -------------

sub get_compl_nodes {
    my ( $self, $arg_ref ) = @_;
    return $self->_get_node_list( 'compl.rf', $arg_ref );
}

sub add_compl_nodes {
    my $self = shift;
    return $self->_add_to_node_list( 'compl.rf', @_ );
}

sub remove_compl_nodes {
    my $self = shift;
    $self->_remove_from_node_list( 'compl.rf', @_ );
    return;
}

sub update_compl_nodes {
    my $self = shift;
    $self->_update_list('compl.rf');
    return;
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

# ---- attributes that contain references

override '_get_reference_attrs' => sub {

    my ($self) = @_;
    return ('a/lex.rf', 'original_parent.rf', 'src_tnode.rf', 'a/aux.rf', 'compl.rf', 'coref_gram.rf', 'coref_text.rf');
};

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
sub gram_diathesis     { return $_[0]->get_attr('gram/diathesis'); }

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
sub set_gram_diathesis     { return $_[0]->set_attr( 'gram/diathesis',     $_[1] ); }

#------------- valency frame reference -----

sub val_frame_rf { return $_[0]->get_attr('val_frame.rf'); }
sub set_val_frame_rf { return $_[0]->set_attr('val_frame.rf', $_[1]); }

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

=item @anodes = $node->get_anodes()

Return a-nodes (both auxiliary and lexical, ie. C<a/aux.rf> and C<a/lex.rf>)

=item @aux_anodes = $node->get_aux_anodes()

Return auxiliary a-nodes (from C<a/aux.rf>).

=item $lex_anod = $node->get_lex_anode()

Return the lexical a-nodes (from C<a/lex.rf>).

=item $node->set_aux_anodes(@aux_anodes)

Set the auxiliary a-nodes (to C<a/aux.rf>).

=item set_lex_anode

Set the lexical a-node (to C<a/lex.rf>).

=item $node->remove_aux_anodes(@to_remove)

Remove the specified a-nodes from C<a/aux.rf> (if they are contained in it).

=item $node->get_coref_nodes()

Return textual and grammatical coreference nodes (from C<coref_gram.rf> and C<coref_text.rf>).
If the document follows the PDT3.0 annotation style, the same steps as for C<$node->get_coref_text_nodes()> are applied.

=item $node->get_coref_gram_nodes()

Return grammatical coreference nodes (from C<coref_gram.rf>).

=item $node->get_coref_text_nodes()

Return textual coreference nodes (from C<coref_text.rf> if the document follows the PDT2.0 annotation style).
If the document follows the PDT3.0 annotation style, the list of nodes is extracted from C<coref_text/target_node.rf>.
If the C<with_types> parameter is set in C<arg_ref>, two list references are returned: the first one refers to a list of nodes
extracted from C<coref_text/target_node.rf>, the second one to a list of types from C<coref_text/type>.

=item $node->add_coref_gram_nodes(@nodes)

Add grammatical coreference nodes (to C<coref_gram.rf>).

=item $node->add_coref_gram_nodes(@nodes)

Add textual coreference nodes (to C<coref_text.rf>).

=item $node->remove_coref_nodes()

Remove the specified nodes from C<coref_gram.rf> or C<coref_text.rf> (if they are contained in one or both of them).

=item $node->update_coref_nodes()

Remove all invalid coreferences from C<coref_gram.rf> and C<coref_text.rf>.

=item $node->get_bridging_nodes()

Access the nodes referred from the current node by bridging anaphora (in C<bridging> attribute).
The method returns references to two lists of the equal length: the referred nodes and the types of bridging relations.

=item $node->add_bridging_node($node, $type)

Add bridging anaphora to C<$node> of type C<$type> (to C<bridging>).

=item $node->get_appos_expansion($arg_ref?)

If the node is part of an apposition (no matter whether as a root
or a member), return all the nodes that constitute the apposition.
Only the apposition root may be excluded from the selection if the
option C<with_appos_root> is off.
The method is used to abstract from the technical implementation
of appositions. So far, it is used by coreference accessors.

OPTIONS

=over

=item with_appos_root

Include the apposition root. Disabled by default.

=back

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

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

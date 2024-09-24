package Treex::Core::Node::U;

use namespace::autoclean;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';
with 'Treex::Core::Node::Ordered';
with 'Treex::Core::Node::InClause';

# u-layer attributes
has [
    qw( nodetype concept functor aspect modal_strength
    )
] => ( is => 'rw' );

sub get_pml_type_name
{
    my ($self) = @_;
    return $self->is_root() ? 'u-root.type' : 'u-node.type';
}

#==============================================================================
# Helpers for reference lists. (Cloned from Treex::Core::Node::T. Maybe these
# helper methods could be inherited from Treex::Core::Node?)
#==============================================================================

sub _get_node_list
{
    my ( $self, $list, $arg_ref ) = @_;
    $list = $self->get_attr($list);
    my $doc = $self->get_document();
    my @nodes = $list ? ( map { $doc->get_node_by_id($_) } @{$list} ) : ();
    return $arg_ref ? $self->_process_switches( $arg_ref, @nodes ) : @nodes;
}

sub _set_node_list
{
    my $self = shift;
    my $list = shift;
    $self->set_attr( $list, [ map { $_->get_attr('id') } @_ ] );
    return;
}

sub _add_to_node_list
{
    my $self = shift;
    my $list = shift;
    # Get the current elements of the list.
    my $cur_ref = $self->get_attr($list);
    my @cur = $cur_ref ? @{$cur_ref} : ();
    # Grep only those that are not already in the list.
    my @new = grep
    {
        my $id = $_;
        !any { $_ eq $id } @cur
    }
    map { $_->get_attr('id') } @_;
    # Set the new list value.
    $self->set_attr( $list, [ @cur, @new ] );
    return;
}

sub _remove_from_node_list
{
    my $self = shift;
    my $list = shift;
    my @prev = $self->_get_node_list($list);
    my @remain;
    foreach my $node (@prev)
    {
        if ( !grep { $_ == $node } @_ )
        {
            push(@remain, $node);
        }
    }
    $self->_set_node_list( $list, @remain );
    return;
}

#==============================================================================
# References to the t-layer (tectogrammatical layer).
#==============================================================================

sub get_tnode
{
    my $self = shift;
    my $t_rf = $self->get_attr('t.rf');
    my $document = $self->get_document();
    return $document->get_node_by_id($t_rf) if $t_rf;
    return;
}

sub get_troot
{
    my $self = shift;
    my $t_rf = $self->get_attr('ttree.rf');
    my $document = $self->get_document();
    return $document->get_node_by_id($t_rf) if $t_rf;
    return;
}

sub set_tnode
{
    my $self = shift;
    my $tnode = shift;
    my $new_id = defined($tnode) ? $tnode->get_attr('id') : undef;
    $self->set_attr('t.rf', $new_id);
    return;
}

sub get_alignment
{
    my ($self) = @_;
    my @a_ids = $self->get_attr('alignment.rf')->values;
    return map $self->get_document->get_node_by_id($_), @a_ids
}

sub copy_alignment
{
    my ($self, $tnode) = @_;
    if (my @anodes = $tnode->get_anodes) {
        $self->set_attr('alignment.rf', [map $_->id, @anodes]);
    }
}



#==============================================================================
# Entity attributes.
#==============================================================================

sub entity_refperson    { return $_[0]->get_attr( 'entity/ref-person' ); }
sub entity_refnumber    { return $_[0]->get_attr( 'entity/ref-number' ); }

sub set_entity_refperson    { return $_[0]->set_attr( 'entity/ref-person',   $_[1] ); }
sub set_entity_refnumber    { return $_[0]->set_attr( 'entity/ref-number',   $_[1] ); }

#==============================================================================
# Reference within the same u-graph for referential nodes.
#==============================================================================

sub get_ref_node
{
    my $self = shift;
    # reference can be obtained only for referential nodes
    return undef if ($self->nodetype ne "ref");
    return $self->get_deref_attr('same_as.rf')
}

sub set_ref_node
{
    my $self = shift;
    my $refnode = shift;
    if ($self->nodetype ne "ref") {
        log_warn("Setting a reference node for the non-referential node $self->id skipped.");
        return;
    }
    $self->set_deref_attr('same_as.rf', $refnode);
}

sub make_referential
{
    my $self = shift;
    my $refnode = shift;
    $self->set_nodetype('ref');
    $self->set_ref_node($refnode);
    $self->set_concept(undef)
}

#==============================================================================
# Document-level coreference.
#==============================================================================

sub get_coref {
    my ($self) = @_;
    my $coref_list = $self->get_attr("coref") // [];
    my $doc = $self->get_document;
    return map {
        [$doc->get_node_by_id($_->{'target_node.rf'}), $_->{'type'}]
    } @$coref_list;
}

sub add_coref {
    my ($self, $uante, $type) = @_;
    $type //= "same-entity";
    my $coref_list = $self->get_attr("coref") // [];
    my $new_coref = {'target_node.rf' => $uante->id, 'type' => $type};
    push @$coref_list, $new_coref;
    $self->set_attr("coref", $coref_list);
}

#==============================================================================
# Attributes that contain references.
#==============================================================================

override '_get_reference_attrs' => sub
{
    my ($self) = @_;
    return qw( t.rf same_as.rf alignment.rf );
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Node::U

=head1 DESCRIPTION

u-layer (Uniform Meaning Representation, UMR) node


=head1 METHODS

=head2 Access to t-layer (tectogrammatical nodes)

=over

=item $tnode = $unode->get_tnode()

Return the corresponding t-node (from C<t.rf>).

=item set_tnode

Set the corresponding t-node (to C<t.rf>).

OPTIONS

=over

=back

=back


=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

Jan Stepanek <stepanek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

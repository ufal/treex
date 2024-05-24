package Treex::Block::T2U::BuildUtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Tool::UMR::PDTV2PB';

has '+language' => ( required => 1 );

sub process_zone
{
    my ( $self, $zone ) = @_;
    my $troot = $zone->get_ttree();
    # Build u-root.
    my $uroot = $zone->create_utree({overwrite => 1});
    $uroot->set_deref_attr('ttree.rf', $troot);
    # Recursively build the tree.
    $self->build_subtree($troot, $uroot);
    # Make sure the ord attributes form a sequence 1, 2, 3, ...
    $uroot->_normalize_node_ordering();
    return 1;
}

sub build_subtree
{
    my ($self, $tparent, $uparent) = @_;
    foreach my $tnode ($tparent->get_children({ordered => 1}))
    {
        my $unode = $uparent->create_child();
        $unode = $self->add_tnode_to_unode($tnode, $unode);
        $self->build_subtree($tnode, $unode);
    }
    return;
}

sub translate_val_frame
{
    my ($self, $tnode, $unode) = @_;
    my @eps = $tnode->get_eparents;
    my %functor;
  EPARENT:
    for my $ep (@eps) {
        next unless $ep->val_frame_rf;

        if (my $valframe_id = $ep->val_frame_rf) {
            $valframe_id =~ s/^.*#//;
            if (my $pb = $self->mapping->{$valframe_id}{ $tnode->functor }) {
                ++$functor{$pb};
                next EPARENT
            }
        }
        ++$functor{ $tnode->functor };
    }
    if (1 == keys %functor) {
        $unode->set_functor((keys %functor)[0]);
    } else {
        warn "More than one functor: ", join ' ', keys %functor
            if keys %functor > 1;
        $unode->set_functor($tnode->functor);
    }
    if (my $valframe_id = $tnode->val_frame_rf) {
        $valframe_id =~ s/^.*#//;
        my $mapping = $self->mapping->{$valframe_id};
        if (my $pb_concept = $mapping->{umr_id}) {
            $unode->set_concept($pb_concept);
            if (grep /ARG[0-9]/, values %$mapping) {
                $unode->set_modal_strength('full-affirmative');
                $unode->set_aspect('activity');  # TODO: Value.
            }
        }
    }
}

sub add_tnode_to_unode
{
    my ($self, $tnode, $unode) = @_;
    $unode->set_tnode($tnode);
    # Set u-node attributes based on the t-node.
    $unode->_set_ord($tnode->ord());
    $unode->set_concept($tnode->t_lemma());
    $self->translate_val_frame($tnode, $unode);
    return $unode
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2U::BuildUtree

=head1 DESCRIPTION

A skeleton of the UMR tree is created from the tectogrammatical tree.

=head1 PARAMETERS

Required:

=over

=item language

=back

Optional:

Currently none.

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

Jan Stepanek <stepanek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

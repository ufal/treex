package Treex::Block::T2U::AdjustStructure;

use Moose;

use Treex::Tool::UMR::Common qw{ get_corresponding_unode };

use namespace::autoclean;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );


sub process_unode {
    my ($self, $unode) = @_;
    my $tnode = $unode->get_tnode;
    $self->adjust_contrd($unode, $tnode) if 'CONTRD' eq $tnode->functor;
    return
};

sub adjust_contrd
{
    my ($self, $unode, $tnode) = @_;
    my $t_parent = $tnode->get_parent;
    my $u_parent = get_corresponding_unode($unode, $t_parent, $unode->root);
    my $operator = $u_parent->parent->create_child;
    $operator->set_concept($unode->functor);
    $operator->set_functor($u_parent->functor);
    $u_parent->set_functor('ARG1');
    $unode->set_functor('ARG2');
    $u_parent->set_parent($operator);
    $unode->set_parent($operator);

    my @auxc = grep 'AuxC' eq $_->afun,
               $unode->get_alignment;
    $unode->_remove_from_node_list('alignment.rf', @auxc);
    $operator->_add_to_node_list('alignment.rf', @auxc);

    return
}

=head1 Treex::Block::T2U::AdjustStructure

=cut


__PACKAGE__

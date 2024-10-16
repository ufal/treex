# -*- encoding: utf-8 -*-
package Treex::Block::T2U::AdjustStructure;
use experimental qw( signatures );

use Moose;

use Treex::Core::Common;
use Treex::Tool::UMR::Common qw{ get_corresponding_unode
                                 is_coord expand_coord };

use namespace::autoclean;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );


sub process_unode($self, $unode, $bundle_no) {
    my $tnode = $unode->get_tnode;
    $self->adjust_contrd($unode, $tnode) if 'CONTRD' eq $tnode->functor;
    $self->adjust_coap($unode, $tnode) if 'coap' eq $tnode->nodetype;
    $self->remove_double_edge($unode, $1, $tnode)
        if $unode->functor =~ /^(.+)-of$/;
    return
}

sub adjust_contrd($self, $unode, $tnode) {
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

sub adjust_coap($self, $unode, $tnode) {
    my @t_members = $tnode->get_coap_members;
    my @t_common = grep {
        my $ch = $_;
        ! grep $ch == $_, @t_members
    } grep ! $_->is_member && 'CM' ne $_->functor, $tnode->children;
    my @u_members = grep 'ref' ne ($_->nodetype // ""),
                    map get_corresponding_unode($unode, $_, $unode->root),
                    @t_members;
   log_warn("No memebers $tnode->{id}"), return
        unless @u_members;

    for my $tcommon (@t_common) {
        my $ucommon = get_corresponding_unode($unode, $tcommon,
                                              $unode->root);
        log_debug("No unode for $tcommon->{id}", 1), next
            unless $ucommon;

        $ucommon->set_parent($u_members[0]);
        for my $other_member (@u_members[1 .. $#u_members]) {
            my $ref = $other_member->create_child;
            $ref->{ord} = 0;
            $ref->set_functor($ucommon->functor);
            $ref->make_referential(('ref' eq ($ucommon->{nodetype} // ""))
                                   ? $self->_solve_ref($ucommon)
                                   : $ucommon);
        }
    }
    return
}

# TODO: tnode not needed?
sub remove_double_edge($self, $unode, $functor, $tnode) {
    my @unodes = expand_coord($unode);
    warn "Expand: ", join ' ', map $_->concept, @unodes;
    for my $uexp (map $_->children, @unodes) {
        warn "Try $uexp->{concept}";
        if ($uexp->functor eq $functor) {
            if ('ref' eq $uexp->{nodetype}) {
                $uexp->remove;
            } else {
                warn "Double $functor $tnode->{id} $uexp->{concept}";
            }
        }
    }
    return
}

sub _solve_ref($self, $unode) {
    while ('ref' eq ($unode->{nodetype} // "")) {
        $unode = $unode->get_document->get_node_by_id($unode->{'same_as.rf'});
    }
    return $unode
}

=encoding utf-8

=head1 NAME

Treex::Block::T2U::AdjustStructure

=head1 DESCRIPTION

Do some structure adjustments after converting a t-layer tree to a u-layer
tree.

=head1 PARAMETERS

Required:

=over

=item language

=back

Optional:

Currently none.

=head1 AUTHORS

Jan Stepanek <stepanek@ufal..mff.cuni.cz>

Copyright © 2024 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__

# -*- encoding: utf-8 -*-
package Treex::Block::T2U::AdjustStructure;

use Moose;

use Treex::Core::Common;
use Treex::Tool::UMR::Common qw{ is_coord expand_coord };
use List::Util qw{ max };

use namespace::autoclean;
use experimental qw( signatures );

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );


my $NEGATION = 'n(?:e|ikoliv?)';
sub process_unode($self, $unode, $) {
    my $tnode = $unode->get_tnode;
    $self->translate_compl($unode, $tnode)
        if 'COMPL' eq $tnode->functor;
    $self->subordinate2coord($unode, $tnode)
        if $tnode->functor =~ /^(?:CONTRD|CNCS)$/;
    $self->adjust_coap($unode, $tnode) if 'coap' eq $tnode->nodetype;
    $self->remove_double_edge($unode, $1, $tnode)
        if $unode->functor =~ /^(.+)-of$/;
    $self->negate_sibling($unode, $tnode)
        if 'RHEM' eq $tnode->functor && $tnode->t_lemma =~ /^$NEGATION$/
        || 'CM' eq $tnode->functor && $tnode->t_lemma =~ /^(?:#Neg|$NEGATION)$/;
    return
}

{   my %SEMPOS2REL = (v => 'manner',
                      a => 'manner',
                      n => 'mod');
    sub translate_compl($self, $unode, $tnode) {
        my $orig_tnode = $tnode;
        my (@compl_targets) = $tnode->get_compl_nodes;
        my $arrow_src = $unode;
        if ($tnode->is_member) {
            $tnode = $tnode->_get_transitive_coap_root;
            ($unode) = $tnode->get_referencing_nodes('t.rf');
        }

        my @parent_sempos = map substr($_, 0, 1),
                            map {
                                $_ ->gram_sempos || do {
                                    log_warn("COMPL $tnode->{id}: "
                                             . "$_->{id} no sempos")
                                        unless '#EmpVerb' eq $_->t_lemma;
                                    'v'
                                }
                            }
                            $orig_tnode->get_eparents;
        my %sempos_freq;
        ++$sempos_freq{$_} for @SEMPOS2REL{@parent_sempos};
        my $relation;
        if (1 < keys %sempos_freq) {
            my $max_freq = max(values %sempos_freq);
            my @most_common = grep $max_freq == $sempos_freq{$_},
                              keys %sempos_freq;
            log_warn("COMPL eparent sempos $tnode->{id}: @most_common");
            $relation = $most_common[0];
        } else {
            $relation = (keys %sempos_freq)[0];
        }

        $unode->set_functor($relation);

        my (@u_targets) = map $_->get_referencing_nodes('t.rf'), @compl_targets;
        for my $u_target (@u_targets) {
            if ($u_target->root == $unode->root) {
                my $ref = $arrow_src->create_child;
                $ref->{ord} = 0;
                $ref->set_functor('mod-of');
                $ref->make_referential(('ref' eq ($u_target->nodetype // ""))
                                   ? $self->_solve_ref($u_target)
                                   : $u_target);
            } else {
                log_warn("$tnode->{id}: COMPL target in other tree.");
            }
        }
    }
}

sub subordinate2coord($self, $unode, $tnode) {
    my $t_parent   = $tnode->get_parent;
    my ($u_parent) = $t_parent->get_referencing_nodes('t.rf');
    my $operator   = $u_parent->parent->create_child;
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

sub negate_sibling($self, $unode, $tnode) {
    my $tparent = $tnode->parent;
    my @tsiblings
        = ('RHEM' eq $tnode->functor) ? $tnode->rbrother
        : 'GRAD' eq $tparent->functor ? $self->_negate_grad($unode, $tnode)
        :                               $self->_parent_side($tnode, $tparent);
    log_warn("0 siblings $tnode->{id}"),
            return
        if ! @tsiblings || ! defined $tsiblings[0];

    @tsiblings = ($tsiblings[0]);
    @tsiblings = $tsiblings[0]->get_coap_members if $tsiblings[0]->is_coap_root;
    my @siblings = map $_->get_referencing_nodes('t.rf'), @tsiblings;
    for my $sibling (@siblings) {
        $sibling->set_polarity;
        if (my $lex = $tnode->get_lex_anode) {
            $sibling->add_to_alignment($lex);
        }
    }
    log_warn("POLARITY $tnode->{id}") if @tsiblings != 1;
    log_warn("POLARITY_M $tnode->{id}") if @siblings > 1;
    log_warn('Remove with children ' . $tnode->id) if $unode->children;
    $unode->remove;
    return
}

sub _negate_grad($self, $unode, $tnode) {
    if (my $rbro = $tnode->rbrother) {
        return $rbro if $rbro->t_lemma =~ /^(?:jen(?:om)?|pouze|výhradně)$/;
    }
    return
}

sub _parent_side($self, $tnode, $tparent) {
    my $is_left = $tnode->ord < $tparent->ord;
    my ($tord, $tpord) = map $_->ord, $tnode, $tparent;
    return sort { abs($a->ord - $tord) <=> abs($b->ord - $tord) }
           grep { ($_->ord <=> $tpord) == ($is_left ? -1 : 1) }
           grep $_->is_member,
           $tparent->children
}

sub adjust_coap($self, $unode, $tnode) {
    my @t_members = $tnode->get_coap_members;
    my @t_common = grep {
        my $ch = $_;
        ! grep $ch == $_, @t_members
    } grep ! $_->is_member
           && 'CM' ne $_->functor
           && ! ('RHEM' eq $_->functor && $_->t_lemma =~ /^$NEGATION$/),
    $tnode->children;
    my @u_members = grep 'ref' ne ($_->nodetype // ""),
                    grep defined || do {
                        log_warn(join ' ', 'UNDEF', map $_->id, @t_members);
                        0
                    },
                    map $_->get_referencing_nodes('t.rf'),
                    @t_members;
   log_warn("No memebers $tnode->{id}"), return
        unless @u_members;

    my $first_member = shift @u_members;
    for my $tcommon (@t_common) {
        my ($ucommon) = $tcommon->get_referencing_nodes('t.rf');
        log_debug("No unode for $tcommon->{id}", 1), next
            unless $ucommon;

        $ucommon->set_parent($first_member);
        for my $other_member (@u_members) {
            my $ref = $other_member->create_child;
            $ref->{ord} = 0;
            $ref->set_functor($ucommon->functor);
            $ref->make_referential(('ref' eq ($ucommon->nodetype // ""))
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
            if ('ref' eq $uexp->nodetype) {
                $uexp->remove;
            } else {
                warn "Double $functor $tnode->{id} $uexp->{concept}";
            }
        }
    }
    return
}

sub _solve_ref($self, $unode) {
    while ('ref' eq ($unode->nodetype // "")) {
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

Jan Stepanek <stepanek@ufal.mff.cuni.cz>

Copyright © 2024 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__

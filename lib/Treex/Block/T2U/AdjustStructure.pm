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

has _coord_members_already_sub2coorded => (is => 'ro', isa => 'HashRef',
                                           default => sub { +{} });

sub process_unode($self, $unode, $) {
    my $negation = $self->negation;
    my $tnode = $unode->get_tnode;
    $self->translate_compl($unode, $tnode)
        if 'COMPL' eq $tnode->functor;
    $self->subordinate2coord($unode, $tnode)
        if $tnode->functor =~ /^(?:CONTRD|CNCS)$/;
    $self->adjust_coap($unode, $tnode) if 'coap' eq $tnode->nodetype;
    $self->remove_double_edge($unode, $1, $tnode)
        if $unode->functor =~ /^(.+)-of$/;
    $self->negate_sibling($unode, $tnode)
        if 'RHEM' eq $tnode->functor && $tnode->t_lemma =~ /^$negation$/
        || 'CM' eq $tnode->functor && $tnode->t_lemma =~ /^(?:#Neg|$negation)$/;
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
    if ($tnode->is_member) {
        $tnode = $tnode->_get_transitive_coap_root;
        ($unode) = $tnode->get_referencing_nodes('t.rf');
        if (! $unode) {
            log_warn($tnode->{id} . ' has no unode for subordinate2coord');
            return
        }
        log_info('Skipping 2nd run'), return
            if $self->_coord_members_already_sub2coorded->{ $unode->id }++;
    }

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
        return $rbro if $self->is_exclusive($rbro->t_lemma);
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
    my $negation = $self->negation;
    my @t_members = $tnode->get_coap_members;
    my @t_common = grep {
        my $ch = $_;
        ! grep $ch == $_, @t_members
    } grep ! $_->is_member
           && $_->functor !~ /^C(?:M|ONTRD|NCS)$/
           && ! ('RHEM' eq $_->functor && $_->t_lemma =~ /^$negation$/),
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

        last if $ucommon->functor =~ /-9/;

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

=over

=item translate_compl

Translates the complement COMPL into a C<manner> or C<mod> based on the sempos
of the parent. The second dependency is translated into a C<mod_of> arrow.

=item subordinate2coord

C<CONTRD> and C<CNCS> are treated as subordinate on t-layer, but they are
translated as C<but-1> in UMR which is coordinate. The structure must be
therefore changed: a new node is created to represent the coordination and
both the C<CONTRD/CNCS> and its parent are rehung to it.

=item adjust_coap

Common dependents in a coordination are rehung to the first coordination
member. Arrows are created from all other members to the common dependents to
express their relation.

=item remove_double_edge

When a C<*-of> relation is created from a coordination, the node sometimes
still have arrows with the inverted relation, too. Remove this surplus arrows.

=item negate_sibling

Non-C<#Neg> negative C<RHEM> and all negative C<CM>'s are translated into the
C<polarity> feature. Special care is needed in C<GRAD> coordinations where the
negation depends on the position of the negation relative to the coordination
head.

=back

=head1 PARAMETERS

=head2 Required:

=over

=item language

=back

=head2 Optional:

Currently none.

=head1 AUTHORS

Jan Stepanek <stepanek@ufal.mff.cuni.cz>

Copyright © 2024 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__

# -*- encoding: utf-8 -*-
package Treex::Block::T2U::AdjustStructure;

use Moose;

use Treex::Core::Common;
use Treex::Tool::UMR::Common qw{ is_coord expand_coord };
use List::Util qw{ max };

use namespace::autoclean;
use experimental qw( signatures );

extends 'Treex::Core::Block';
with 'Treex::Tool::UMR::RelationSetter';

has '+language' => ( required => 1 );

has coref2fix => (is => 'rw', isa => 'HashRef', default => sub { +{} });
has remove_later => (is => 'rw', isa => 'HashRef', default => sub { +{} });

has _coord_members_already_sub2coorded => (is => 'ro', isa => 'HashRef',
                                           default => sub { +{} });

sub process_unode($self, $unode, $) {
    return if $unode->is_root;

    my $negation = $self->negation;

    # Not yet removed INTF (not part of coreference).
    if ($unode->functor =~ /^(?:!!)?INTF$/) {
        log_warn("Remove INTF with children ", $unode->id) if $unode->children;
        log_debug("Removed INTF " . $unode->id);
        $unode->remove;
        return
    }

    if ('#Forn' eq ($unode->concept // "")) {
        if ('name' eq $unode->functor) {
            $self->translate_forn($unode, 'name', 1);
        } else {
            $self->translate_forn($unode, 'foreign-phrase', 0);
        }
    }

    if ('%AsMuch' eq ($unode->concept // "")) {
        $unode->set_concept('have-degree-91');
        for my $resl (grep 'result' eq $_->functor, $unode->get_children) {
            warn "AsMuch: $resl->{id}";
            $self->set_relation($resl, 'ARG6', $resl->get_tnode);
        }
    }

    my $tnode = $unode->get_tnode;
    $self->translate_compl($unode, $tnode)
        if 'COMPL' eq $tnode->functor;
    $self->adjust_coap($unode, $tnode) if 'coap' eq $tnode->nodetype;
    $self->translate_percnt($unode, $tnode)
        if 'percentage-entity' eq ($unode->concept // "");
    $self->simplify_double_edges($unode);
    $self->remove_backwards_edge($unode, $1, $tnode)
        if $unode->functor =~ /^(.+)-of$/;
    $self->negate_sibling($unode, $tnode)
        if 'RHEM' eq $tnode->functor && $tnode->t_lemma =~ /^$negation$/
        || 'CM' eq $tnode->functor && $tnode->t_lemma =~ /^(?:#Neg|$negation)$/;
    return
}

sub translate_forn($self, $unode, $concept, $threshold) {
    $unode->set_concept($concept);
    my @fphrs;
    for my $child ($unode->children) {
        if ('!!FPHR' eq $child->functor) {
            push @fphrs, [$child->get_tnode];
            $unode->add_to_alignment($child->get_alignment);
            $self->safe_remove($child, $unode);
        } else {
            log_warn("#Forn with non-FPHR child: $unode->{id}");
        }
    }
    if (@fphrs) {
        my $i = 0;
        while ($i < $#fphrs) {
            my $tnode = $fphrs[$i][-1];
            my $alex = $tnode->get_lex_anode;
            if (! $alex) {
                warn join ' ', "No alex", $tnode->id, $unode->id;
                ++$i
            } elsif ($alex->no_space_after) {
                push @{ $fphrs[$i] }, @{ splice @fphrs, $i + 1, 1 };
            } else {
                ++$i;
            }
        }
        my @ops = map join("", map $_->t_lemma, @$_), @fphrs;
        log_warn(join ' ', 'No FPHRs', $unode->id) unless @ops;
        if (@ops > $threshold) {
            $unode->set_ops(Treex::PML::Factory->createList(\@ops));
        } else {
            $unode->set_concept($ops[0]);
        }
    } else {
        log_warn("#Forn without FPHR children: $unode->{id}");
    }
}

sub translate_percnt($self, $unode, $tnode) {
    my @quants = grep +($_->gram_sempos // "") =~ /quant/
                      || $_->t_lemma =~ /^[0-9]+(?:\.[0-9]+)?$/,
                 $tnode->get_echildren;
    for my $quant (@quants) {
        push @quants, $quant->parent
            if $quant->is_member && ! grep $quant->parent == $_, @quants;
    }
    my @aquants = sort { $a->ord <=> $b->ord } map $_->get_lex_anode, @quants;
    $unode->set_value(join ' ', map $_->form, @aquants);
    for my $quant (@quants) {
        warn "QUANT: No unode for $_->{id}"
            if ! $quant->get_referencing_nodes('t.rf');
    }
    my @uquants = map $_->[0],
                  sort { $b->[1] <=> $a->[1] }
                  map [$_, $self->_depth($_)],
                  map $_->get_referencing_nodes('t.rf'),
                  @quants;
    my @rest = grep { my $d = $_;
                      ! grep $d == $_, @uquants
               } map $_->children, @uquants;
    for my $r (@rest) {
        $r->set_parent($unode);
        if ('extent' eq $r->functor) {
            if (my $t = $r->get_tnode) {
                warn('COAP PERCNT ' . $r->{id}),
                $t = ($t->get_coap_members)[0] if 'coap' eq $t->nodetype;
                $r->set_functor('degree') if 'EXT' eq $t->functor;
            }
        }
    }
    for my $uquant (@uquants) {
        $unode->add_to_alignment($uquant->get_alignment);
        $self->safe_remove($uquant, $unode);
    }
}

sub _depth($self, $unode) {
    my $depth = 0;
    my $node = $unode;
    ++$depth, $node = $node->parent while $node->parent;
    return $depth
}

sub translate_compl($self, $unode, $tnode) {
    my $orig_tnode = $tnode;
    my (@compl_targets) = $tnode->get_compl_nodes;
    my $arrow_src = $unode;
    if ($tnode->is_member) {
        $tnode = $tnode->_get_transitive_coap_root;
        ($unode) = $tnode->get_referencing_nodes('t.rf');
    }

    my $relation = $self->sempos2relation($orig_tnode->parent);
    warn "COMPL ", $orig_tnode->parent->t_lemma // '?', ' ', $relation;
    $unode->set_functor($relation);

    # COMPL as a common dependent.
    for my $u ($unode->root->descendants) {
        next if ($u->{'same_as.rf'} // "") ne $unode->id
             || ($u->functor // "") !~ /^(?:!!)?COMPL$/;
        $u->set_functor($self->sempos2relation($u->parent->get_tnode));
    }

    my (@u_targets) = map $_->get_referencing_nodes('t.rf'), @compl_targets;
    for my $u_target (@u_targets) {
        if ($u_target->root == $unode->root) {
            my $ref = $arrow_src->create_child;
            $ref->{ord} = 0;
            $ref->set_functor('mod-of');
            $ref->make_referential($self->_solve_ref($u_target));
        } else {
            log_warn("$tnode->{id}: COMPL target in other tree.");
        }
    }
}

{   my %SEMPOS2REL = (v => 'manner',
                      a => 'manner',
                      n => 'mod');
    sub sempos2relation($self, $tnode) {
        my $sempos = substr $tnode->gram_sempos || do {
                log_warn("COMPL $tnode->{id}: "
                         . "$_->{id} no sempos")
                    unless '#EmpVerb' eq $tnode->t_lemma;
                    'v'
        }, 0, 1;
        return $SEMPOS2REL{$sempos}
    }
}

sub negate_sibling($self, $unode, $tnode) {
    my $tparent = $tnode->parent;
    my @tsiblings
        = ('RHEM' eq $tnode->functor) ? ('f' eq ($tnode->tfa // "")
                                             && ! $tnode->rbrother
                                         ? $tnode->parent
                                         : $tnode->rbrother)
        : 'GRAD' eq $tparent->functor ? $self->_negate_grad($tnode)
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

# Remove a node, all coref chains going through it should go through
# its parent (or any other node specified) instead.
sub safe_remove($self, $node, $parent) {
    log_debug("Safe remove $node->{id}, reroute to $parent->{id}");
    if (my $coref = $node->get_attr('coref')) {
        $parent->set_attr('coref', [@{ $parent->get_attr('coref') // [] },
                                    @$coref]);
    }
    $self->coref2fix->{ $node->id } = $parent->id;
    if (grep ! exists $self->remove_later->{ $_->id }, $node->children) {
        log_warn('Removing with children ' . $node->id);
    } else {
        # We can't remove the node now, as it would remove all
        # references to it, including same_as.rf.
        undef $self->remove_later->{ $node->id };
    }
    return
}

after process_document => sub($self, $document) {
    $self->fix_coref($document);
    $self->rename_octothorpes($document);
};

sub rename_octothorpes($self, $document) {
    for my $tree ($document->trees) {
        for my $node ($tree->descendants) {
            next unless $node->isa('Treex::Core::Node::U')
                 && defined $node->concept;
            $node->set_concept($node->concept =~ s/^#/%/r)
                if $node->concept =~ /^#/;
        }
    }
}

sub fix_coref($self, $document) {
    return unless keys %{ $self->coref2fix };

    for my $tree ($document->trees) {
        for my $node ($tree->descendants) {
            next unless $node->isa('Treex::Core::Node::U');

            if (my $coref = $node->get_attr('coref')) {
                my @new_coref = map
                    exists $self->coref2fix->{ $_->{'target_node.rf'} }
                    ? {type => $_->{type},
                       'target_node.rf'
                           => $self->coref2fix->{ $_->{'target_node.rf'} }}
                    : $_,
                    @$coref;
                $node->set_attr('coref', \@new_coref);
            }
            if (my $same = $node->{'same_as.rf'}) {
                $node->set_attr('same_as.rf', $self->coref2fix->{$same})
                    if exists $self->coref2fix->{$same};
            }
        }
    }
    # Now it's safe to remove the nodes.
    for my $tree ($document->trees) {
        for my $node ($tree->descendants) {
            next unless $node->isa('Treex::Core::Node::U');
            $node->remove if exists $self->remove_later->{ $node->id };
        }
    }
    return
}

sub is_exclusive { die 'Not implemented, language specific' }

sub negation { die 'Not implemented, language specific' }

sub _negate_grad($self, $tnode) {
    if (my $rbro = $tnode->rbrother) {
        return $rbro if $self->is_exclusive($rbro->t_lemma);
    }
    return $self->_parent_side($tnode, $tnode->parent)
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
           && $_->functor !~ /^(?:CM|INTF)$/
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
            $ref->make_referential($self->_solve_ref($ucommon));
        }
    }

    for my $ref (grep 'ref' eq $_->nodetype, $unode->children) {
        $ref->set_parent($first_member);
        for my $member (@u_members) {
            my $ref2 = $member->create_child;
            $ref2->{ord} = 0;
            $ref2->set_functor($ref->functor);
            $ref2->make_referential($self->_solve_ref($ref));
        }
    }
    return
}

# TODO: tnode not needed?
sub remove_backwards_edge($self, $unode, $functor, $tnode) {
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

sub simplify_double_edges($self, $unode) {
    my %ref;
    for my $child (grep 'ref' ne $_->nodetype, $unode->children) {
        ++$ref{ $child->{functor} }{ $child->id };
    }
    for my $child (grep 'ref' eq $_->nodetype, $unode->children) {
        if ($ref{ $child->{functor} }{ $child->{'same_as.rf'} }++) {
            $child->remove;
        }
    }
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

=item adjust_coap

Common dependents in a coordination are rehung to the first coordination
member. Arrows are created from all other members to the common dependents to
express their relation.

=item remove_backwards_edge

When a C<*-of> relation is created from a coordination, the node sometimes
still have arrows with the inverted relation, too. Remove this surplus arrows.

=item simplify_double_edges

Sometimes, a node has several arrows to the same target with the same relation. Keep only a single arrow. Similarly, remove arrows that duplicate edges.

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

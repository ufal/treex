# -*- encoding: utf-8 -*-
package Treex::Block::T2U::ConvertCoreference;

use Moose;
use utf8;
use Treex::Core::Common;
use Treex::Tool::UMR::Common qw{ get_corresponding_unode };

use Graph::Directed;
use namespace::autoclean;


extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has '_tcoref_graph' => ( is => 'rw', isa => 'Graph::Directed' );

sub process_tnode {
    my ($self, $tnode) = @_;

    my @tantes = map $_->get_coap_members, $tnode->get_coref_nodes;
    return unless @tantes;

    if (@tantes > 1) {
        log_warn("Tnode ".$tnode->id." has more than a single antecedent. Selecting the closer one.");
        if ($tnode->root != $tantes[0]->root) {
            @tantes = $tantes[-1];

        } else {
            my $closest = shift @tantes;
            for my $tante (@tantes) {
                $closest = $tante
                    if _path_length($tnode, $tante)
                       < _path_length($tnode, $closest);
            }
            @tantes = $closest;
        }
    }
    my $tante = $tantes[0];
    my $tcoref_graph = $self->_tcoref_graph;
    $tcoref_graph->add_edge($tnode->id, $tante->id);
}

before 'process_document' => sub {
    my ($self, $doc) = @_;
    my $tcoref_graph = Graph::Directed->new();
    $self->_set_tcoref_graph($tcoref_graph);
};

my $RELATIVE = '(?:který|jenž|jaký|co|kd[ye]|odkud|kudy|kam)';

after 'process_document' => sub {
    my ($self, $doc) = @_;

    my $tcoref_graph = $self->_tcoref_graph;

    my @tcoref_sorted = ();

    eval {
        @tcoref_sorted = $tcoref_graph->topological_sort();
    }
    or do {
        my @cycle_nodes = $tcoref_graph->find_a_cycle;
        while (@cycle_nodes) {
            log_warn("A coreference cycle found: " . join(" ", @cycle_nodes) . ". Skipping.");
            $tcoref_graph = $tcoref_graph->delete_cycle(@cycle_nodes);
            @cycle_nodes = $tcoref_graph->find_a_cycle;
        }
        @tcoref_sorted = $tcoref_graph->topological_sort();
    };

    foreach my $tnode_id (@tcoref_sorted) {
        my $tnode = $doc->get_node_by_id($tnode_id);
        my ($unode) = $tnode->get_referencing_nodes('t.rf');

        my ($tante_id) = $tcoref_graph->successors($tnode_id);

        if (defined $tante_id) {
            my $tante = $doc->get_node_by_id($tante_id);
            my ($uante) = $tante->get_referencing_nodes('t.rf');

            # inter-sentential link
            # - the link must be represented by the ":coref" attribute
            # - the following intra-sentential links with underspecified anaphors
            #   must be anchored in this node
            if ($unode->root != $uante->root) {
                $unode->add_coref($uante);
                $self->_anchor_references($unode);
            }
            # intra-sentential links with underspecified anaphors
            # - propagate such anaphors via the wild attribute `anaphs`
            elsif ($tnode->t_lemma
                       =~ /^(?:#(?:Q?Cor|PersPron)|$RELATIVE)$/
                   && ! $tnode->children
            ) {
                $self->_same_sentence_coref(
                    $tnode, $unode, $uante, $tante_id, $doc);
                if ($tnode->t_lemma =~ /^$RELATIVE$/) {
                    $self->_relative_coref(
                        $tnode, $unode, $uante->id, $tante_id, $doc);
                }
            } else {
                $unode->add_coref($uante);
                $self->_anchor_references($unode);
                log_warn("Unsolved coref $tnode_id $tante_id");
            }
        }
        # non-anaphoric antecedent
        # - the following intra-sentential links with underspecified anaphors
        #   must be anchored in this node
        else {
            $self->_anchor_references($unode);
        }
    }
};

sub _same_sentence_coref {
    my ($self, $tnode, $unode, $uante, $tante_id, $doc) = @_;
    for my $predecessor (
        $self->_tcoref_graph->predecessors($tnode->id)
    ) {
        $self->_tcoref_graph->delete_edge($predecessor, $tnode->id);
        $self->_tcoref_graph->add_edge($predecessor, $tante_id);

        my $upred = get_corresponding_unode(
            $unode, $doc->get_node_by_id($predecessor));
        if (my $coref = $upred->{coref}) {
            my $i = (-1,
                     grep $coref->[$_]{'target_node.rf'} eq $unode->id,
                          0 .. $coref->count - 1)[-1];
            if ($i >= 0) {
                $coref->[$i]{'target_node.rf'} = $uante->id;
            }
        } elsif ($upred->{'same_as.rf'}) {
            log_debug("SAME COREF $predecessor/$upred->{concept}, $tnode->{id}/$unode->{concept}", 1);
            $upred->make_referential($uante);
        } else {
            log_warn("CANNOT COREF $upred->{id}/$upred->{concept}, $unode->{id}/$unode->{concept}");
        }
    }
    if ($unode->children) {
        log_warn(sprintf "Cannot turn %s (%s) into REF because of CHILDREN",
                 map $_->id, $unode, $tnode);
    } else {
        $unode->make_referential($uante);
    }
}

# TODO: Coordinated verbs only if all of them share the "ktery" (see wsj2454.cz)
# $tnode is "ktery", $up is a RSTR verb, $gp is a coref antecedent.
sub _relative_coref {
    my ($self, $tnode, $unode, $uante_id, $tante_id, $doc) = @_;
    my $remove;
    my $parent = $tnode->parent;

    my @eparents = $tnode->get_eparents;
    my @rstr_eparents = grep 'RSTR' eq $_->functor, @eparents;

    # There is a non-RSTR parent, we can't proceed.
    log_debug("Non RSTR parent $tnode->{id}", 1),
    return if @eparents != @rstr_eparents;

    log_warn("parent not same as eparents $tnode->{id}"),
    return if 'coap' ne $parent->nodetype
           && @eparents != 1
           && $eparents[0] != $parent;

    if ($parent->parent->id ne $tante_id
        && ($parent->_get_transitive_coap_root // {id => ""})->{id} ne $tante_id
    ) {
        log_debug("Cannot create *-of: $tnode->{id}/$tnode->{t_lemma} "
                  . "$parent->{id}/$parent->{t_lemma} "
                  . $tante_id, 1);
        return
    }

    my $uparent = $unode->parent;
    $uparent->set_functor($unode->functor . '-of');
    $unode->remove;
}

sub _anchor_references {
    my ($self, $unode) = @_;

    # make a reference to this node from all following non-nominal anaphors
    my $unode_anaphs = delete $unode->wild->{'anaphs'} // [];
    foreach my $uanaph (@$unode_anaphs) {
        $uanaph->make_referential($unode);
    }
    my ($person, $number) = $self->_infere_entity_info($unode, @$unode_anaphs);
    $unode->set_entity_refperson($person) if defined $person;
    $unode->set_entity_refnumber($number) if defined $number;
}

my %T2U_PERSON = (
    "1" => "1st",
    "2" => "2nd",
    "3" => "3rd",
    "inher" => "Inher",
);
my %T2U_NUMBER = (
    "sg" => "singular",
    "pl" => "plural",
    "inher" => "inher",
);

sub _infere_entity_info {
    my ($self, $unode, @uanaphs) = @_;

    my $tnode = $unode->get_tnode;

    my $person;
    my $number;
    if (defined $tnode) {
        $person = $tnode->gram_person ? $T2U_PERSON{$tnode->gram_person} : undef;
        $number = $tnode->gram_number ? $T2U_NUMBER{$tnode->gram_number} : undef;
    }
    return ($person, $number);
}

sub _propagate_anaphors {
    my ($self, $unode, $uante) = @_;
    my $unode_anaphs = delete $unode->wild->{'anaphs'} // [];
    push @$unode_anaphs, $unode;
    my $uante_anaphs = $uante->wild->{'anaphs'} // [];
    push @$uante_anaphs, @$unode_anaphs;
    $uante->wild->{'anaphs'} = $uante_anaphs;
}

sub _rank {
    my ($node) = @_;
    my $rank = 0;
    $node = $node->parent, ++$rank while $node->parent;
    return $rank
}

sub _path_length {
    my ($node1, $node2) = @_;
    my @ranks = map _rank($_), $node1, $node2;
    my ($n1, $n2) = ($node1, $node2);
    my $cmp = $ranks[0] <=> $ranks[1];
    my $length = abs($ranks[0] - $ranks[1]);
    warn "LENGTH: $n1->{id} $n2->{id} = $length";
    if ($cmp) {
        my $move_up = {-1 => \$n2, 1 => \$n1}->{$cmp};
        $$move_up = $$move_up->parent for 1 .. $length;
    }
    while ($n1 != $n2) {
        $length += 2;
        $_ = $_->parent for $n1, $n2;
    }
    return $length
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::T2U::ConvertCoreference

=head1 DESCRIPTION

Tecto-to-UMR converter of coreference relations.
It converts all coreferential links from the t- to the u-layer.
Three kinds of representation of tecto-like coreference are distinguished:
1. inversed participant role
2. reference to a concept within the same graph
3. document-level coreference annotation

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

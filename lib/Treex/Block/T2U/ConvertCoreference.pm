package Treex::Block::T2U::ConvertCoreference;

use Moose;
use utf8;
use Treex::Core::Common;

use Graph::Directed;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has '_tcoref_graph' => ( is => 'rw', isa => 'Graph::Directed' );

sub process_tnode {
    my ($self, $tnode) = @_;

    my @tantes = $tnode->get_coref_nodes;
    return if !@tantes;

    if (@tantes > 1) {
        log_warn("Tnode ".$tnode->id." has more than a single antecedent. Taking the first, skipping the rest.");
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
            elsif ($tnode->t_lemma =~ /^#(?:Q?Cor|PersPron)$/
                   && ! $tnode->children
            ) {
                $self->_same_sentence_coref(
                    $tnode, $unode, $uante, $tante_id, $doc);
            }
            # intra-sentential links with nominal anaphors
            # - the link must be represented by the ":coref" attribute
            # - the following intra-sentential links with underspecified anaphors
            #   must be anchored in this node
            elsif (($tnode->gram_sempos // "") =~ /^n/
                    && $tnode->t_lemma =~ /^(?:který|jaký|co|kd[ye])$/
               ) {
                my $remove = $self->_relative_coref(
                    $tnode, $unode, $uante->id, $tante_id, $doc);
                if ($remove && ! $unode->children) {
                    $unode->remove;
                } else {
                    warn "NO REMOVE $tnode->{id}/$tnode->{t_lemma}\n";
                }
            } else {
                $unode->add_coref($uante);
                $self->_anchor_references($unode);
                log_warn("Unsolved coref $unode->{id}");
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
        $self->_tcoref_graph->predecessors($tnode->{id})
    ) {
        $self->_tcoref_graph->delete_edge($predecessor, $tnode->{id});
        $self->_tcoref_graph->add_edge($predecessor, $tante_id);

        my $upred = $self->_get_corresponding_unode(
            $unode, $doc->get_node_by_id($predecessor));
        if (my $coref = $upred->{coref}) {
            my $i = (-1,
                     grep $coref->[$_]{'target_node.rf'} eq $unode->id,
                          0 .. $coref->count - 1)[-1];
            if ($i >= 0) {
                $coref->[$i]{'target_node.rf'} = $uante->id;
            }
        } elsif (my $coref = $upred->{'same_as.rf'}) {
            $upred->{'same_as.rf'} = $uante->id;
        } else {
            warn "CANNOT COREF $upred->{id}/$upred->{concept}, $unode->{id}/$unode->{concept}\n";
        }
    }
    warn "CHILDREN" if $unode->children;
    $unode->{nodetype} = 'ref';
    $unode->{'same_as.rf'} = $uante->id;
}

sub _get_corresponding_unode {
    my ($self, $any_unode, $tnode) = @_;
    my ($u) = grep $_->get_tnode == $tnode,
              map $_->descendants,
              map $_->get_tree($any_unode->language, 'u'),
              $any_unode->get_document->get_bundles;
    return $u
}

sub _relative_coref {
    my ($self, $tnode, $unode, $uante_id, $tante_id, $doc) = @_;
    my $remove;
    my @rstr_eparents = grep 'RSTR' eq $_->functor,
                        $tnode->get_eparents;
    for my $parent (@rstr_eparents) {
        my $up = $self->_get_corresponding_unode($unode, $parent);
        my @grandparents = $parent->get_eparents;
        for my $gp (@grandparents) {
            if ($gp->id eq $tante_id) {
                $up->set_functor($unode->functor . '-of');
                for my $predecessor (
                    $self->_tcoref_graph->predecessors($tnode->{id})
                ) {
                    $self->_tcoref_graph->delete_edge(
                        $predecessor, $tnode->{id});
                    $self->_tcoref_graph->add_edge(
                        $predecessor, $tante_id);
                    my $upred = $self->_get_corresponding_unode(
                        $unode, $doc->get_node_by_id($predecessor));
                    if (my $coref = $upred->{coref}) {
                        my $i = (-1,
                                 grep $coref->[$_]{'target_node.rf'} eq $unode->id,
                                      0 .. $coref->count - 1)[-1];
                        if ($i >= 0) {
                            $coref->[$i]{'target_node.rf'} = $uante_id;
                        }
                    } elsif (my $same = $upred->{'same_as.rf'}) {
                        $upred->{'same_as.rf'} = $uante_id;
                    } else {
                        warn "REL CANNOT COREF $upred->{id}/$upred->{concept}, $unode->{id}/$unode->{concept}\n";
                    }
                }
                $remove = 1;
            }
        }
    }
    return $remove
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

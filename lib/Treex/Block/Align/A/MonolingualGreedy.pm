package Treex::Block::Align::A::MonolingualGreedy;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'to_language' => (
    is         => 'ro',
    isa        => 'Treex::Type::LangCode',
    lazy_build => 1,
);

has 'to_selector' => (
    is      => 'ro',
    isa     => 'Treex::Type::Selector',
    default => 'ref',
);

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

has '+language' => ( required => 1 );

sub BUILD {
    my ($self) = @_;
    log_info( $self->language );
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

my ( $ref_length, $tst_length );
my $min_score_limit = 4;

my %weight = (
    lemma_similarity       => 7,
    tag_similarity         => 6,
    aligned_left_neighbor  => 3,
    aligned_right_neighbor => 3,
    ord_similarity         => 5,
);

sub process_zone {
    my ( $self, $tst_zone ) = @_;
    my $ref_zone = $tst_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    my @tst_nodes = $tst_zone->get_atree->get_descendants( { ordered => 1 } );
    my @ref_nodes = $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    return if @ref_nodes == 0;    # because of re-segmentation

    my %ref_free = map { $_ => $_ } @ref_nodes;
    my %tst_free = map { $_ => $_ } @tst_nodes;
    $ref_length = @ref_nodes;
    $tst_length = @tst_nodes;

    # First, try super-greedy alignment (to make it faster):
    # If there is only one node with the same form, align it.
    my %ref_forms;
    foreach my $ref_node (@ref_nodes) {
        if ( $ref_forms{ $ref_node->form } ) {
            $ref_forms{ $ref_node->form } = 1;
        }
        else {
            $ref_forms{ $ref_node->form } = $ref_node;
        }
    }
    foreach my $tst_node (@tst_nodes) {
        my $ref_node = $ref_forms{ $tst_node->form };
        if ( $ref_node && $ref_node != 1 ) {
            $tst_node->add_aligned_node( $ref_node );
            delete $ref_free{$ref_node};
            delete $tst_free{$tst_node};
        }
    }

    # If there is only one node with the same lemma, align it.
    my %ref_lemmas;
    foreach my $ref_node ( values %ref_free ) {
        my $lemma = $self->get_lemma($ref_node);
        if ( $ref_lemmas{$lemma} ) {
            $ref_lemmas{$lemma} = 1;
        }
        else {
            $ref_lemmas{$lemma} = $ref_node;
        }
    }
    foreach my $tst_node ( values %tst_free ) {
        my $ref_node = $ref_lemmas{ $self->get_lemma($tst_node) };
        if ( $ref_node && $ref_node != 1 ) {
            $tst_node->add_aligned_node( $ref_node );
            delete $ref_free{$ref_node};
            delete $tst_free{$tst_node};
        }
    }

    while (1) {
        my $max_score = 0;
        my ( $ref_winner, $tst_winner );

        foreach my $tst_node ( values %tst_free ) {
            foreach my $ref_node ( values %ref_free ) {
                my $score = $self->score( $tst_node, $ref_node );
                if ( $score > $max_score ) {
                    $max_score  = $score;
                    $ref_winner = $ref_node;
                    $tst_winner = $tst_node;
                }
            }
        }

        last if $max_score < $min_score_limit;
        $tst_winner->add_aligned_node( $ref_winner );
        delete $ref_free{$ref_winner};
        delete $tst_free{$tst_winner};
    }
    return;
}

sub get_lemma {
    my ( $self, $anode ) = @_;
    log_fatal "ha" if !$anode;
    my $lemma = $anode->lemma;
    if ( !defined $lemma ) {
        $lemma = $anode->form;
    }
    $lemma =~ s/[-_].*//;    # trim artificial lemma endings
    return lc $lemma;
}

sub score {
    my ( $self, $tst_node, $ref_node ) = @_;
    my %feature_vector;

    $feature_vector{lemma_similarity} = $self->lemma_similarity( $tst_node, $ref_node );
    $feature_vector{tag_similarity} = $self->tag_similarity( $tst_node, $ref_node );

    my $tst_prev = $tst_node->get_prev_node;
    my $tst_next = $tst_node->get_next_node;
    my $ref_prev = $ref_node->get_prev_node;
    my $ref_next = $ref_node->get_next_node;

    if ( $tst_prev and $ref_prev and ( $tst_prev->get_attr('align') || '' ) eq $ref_prev->id ) {
        $feature_vector{aligned_left_neighbor} = 1;
    }

    if ( $tst_next and $ref_next and ( $tst_next->get_attr('align') || '' ) eq $ref_next->id ) {
        $feature_vector{aligned_right_neighbor} = 1;
    }

    my $ref_rel_ord = $ref_node->ord / $ref_length;
    my $tst_rel_ord = $tst_node->ord / $tst_length;
    $feature_vector{ord_similarity} = 1 - abs( $ref_rel_ord - $tst_rel_ord );

    my $score = 0;
    foreach my $feature_name ( keys %feature_vector ) {
        $score += $feature_vector{$feature_name}
            * ( $weight{$feature_name} or log_fatal "Unknown feature $feature_name" );
    }
    return $score;
}

use Text::JaroWinkler;

sub lemma_similarity {
    my ( $self, $tst_node, $ref_node ) = @_;
    my $tst_lemma = $self->get_lemma($tst_node);
    my $ref_lemma = $self->get_lemma($ref_node);
    return Text::JaroWinkler::strcmp95( $tst_lemma, $ref_lemma, 20 );
}

sub tag_similarity {
    my ( $self, $tst_node, $ref_node ) = @_;
    return 0 if !$tst_node->tag or !$ref_node->tag;
    return substr( $tst_node->tag, 0, 1 ) eq substr( $ref_node->tag, 0, 1 );
}

1;

# Copyright 2011 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::Align::T::AlignGeneratedNodes;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;
extends 'Treex::Core::Block';

has 'to_language' => (
    is         => 'ro',
    isa        => 'Treex::Type::LangCode',
    lazy_build => 1,
);

has 'to_selector' => (
    is      => 'ro',
    isa     => 'Treex::Type::Selector',
    default => 'trg',
);

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

has '+language' => ( required => 1 );

sub BUILD {
    my ($self) = @_;
#    log_info( $self->language );
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

my $min_score_limit = 4;

my %weight = (
    lemma_equality         => 20,
    aligned_parent         => 6,
    aligned_eparents        => 5,
    aligned_siblings        => 3,
    functor_equality        => 2,
);

sub process_zone {
    my ( $self, $ref_zone ) = @_;
    
    my $auto_zone = $ref_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    
    my @ref_nodes = grep {$_->is_generated} $ref_zone->get_ttree->get_descendants( { ordered => 1 } );
    my @auto_nodes = grep {$_->is_generated} $auto_zone->get_ttree->get_descendants( { ordered => 1 } );
    return if @auto_nodes == 0;

    my $ref_free = { map { $_->id => $_ } @ref_nodes };
    my $auto_free = { map { $_->id => $_ } @auto_nodes };
    
    $self->align_generated_nodes_by_tlemma_topology($ref_free, $auto_free);
    $self->align_generated_nodes_by_functor_parent($auto_free);
}

sub align_generated_nodes_by_tlemma_topology {
    my ( $self, $ref_free, $auto_free ) = @_;

    while ((scalar (keys %$auto_free) > 0) && (scalar (keys %$ref_free) > 0)) {
        my $max_score = 0;
        my ( @winners );

        foreach my $ref_node ( values %$ref_free ) {
            foreach my $auto_node ( values %$auto_free ) {
                my $score = $self->score( $ref_node, $auto_node );
                if ( $score > $max_score ) {
                    $max_score  = $score;
                    @winners = ( [$ref_node, $auto_node] );
                }
                elsif ( $score == $max_score ) {
                    push @winners, [$ref_node, $auto_node];
                }
            }
        }
        
        # DEBUG
        # print STDERR "NODES: $max_score\n";

        last if $max_score < $min_score_limit;
        foreach my $winner (@winners) {
            
            # DEBUG
            # print  STDERR "[" . $winner->[0]->id . ", " . $winner->[1]->id . "]" . "\n";
            
            $winner->[0]->add_aligned_node( $winner->[1], 'monolingual' );
            delete $ref_free->{$winner->[0]->id};
            delete $auto_free->{$winner->[1]->id};
        }
    }
    return;
}

sub compare_aligned_nodes {
    my ($self, $ref_nodes, $auto_nodes) = @_;
    my %auto_nodes_ids = map {$_->id => 1} @$auto_nodes;

    my @ref_nodes_trg = map {
        $_->get_aligned_nodes_of_type('monolingual');
    } @$ref_nodes;
    my $both_count = () = grep {$auto_nodes_ids{$_->id}} @ref_nodes_trg;
    my $ref_count = scalar @ref_nodes_trg;
    my $auto_count = scalar @$auto_nodes;

    return 1 if (($ref_count == 0) && ($auto_count == 0));
    return 2 * $both_count / ($ref_count + $auto_count);
}

sub score {
    my ( $self, $ref_node, $auto_node ) = @_;
    my %feature_vector;

    $feature_vector{lemma_equality} = $ref_node->t_lemma eq $auto_node->t_lemma;
    $feature_vector{functor_equality} = $ref_node->functor eq $auto_node->functor;

    my $ref_par = $ref_node->get_parent;
    
    $feature_vector{aligned_parent} = $ref_par->is_directed_aligned_to($auto_node->get_parent, {rel_types => ['monolingual']}) ? 1 : 0;
    
    my @src_eparents = $ref_node->get_eparents({or_topological=>1});
    my @trg_eparents = $auto_node->get_eparents({or_topological=>1});

    $feature_vector{aligned_eparents} = $self->compare_aligned_nodes(\@src_eparents, \@trg_eparents);

    my @ref_siblings = $ref_node->get_siblings;
    my @auto_siblings = $auto_node->get_siblings;

    $feature_vector{aligned_siblings} = $self->compare_aligned_nodes(\@ref_siblings, \@auto_siblings);

    my $score = 0;
    foreach my $feature_name ( keys %feature_vector ) {
        $score += $feature_vector{$feature_name}
            * ( $weight{$feature_name} or log_fatal "Unknown feature $feature_name" );
    }

    return $score;
}

sub align_generated_nodes_by_functor_parent {
    my ($self, $auto_free ) = @_;

    foreach my $auto_node (values %$auto_free) {
        my $auto_par = $auto_node->get_parent;
        next if (!$auto_par);
        my ($ref_par) = Treex::Tool::Align::Utils::aligned_transitively([$auto_par], [{rel_types => ['monolingual']}]);
        next if (!$ref_par);
        next if (!$ref_par->is_member);
        my ($ref_eq) = grep {$_->functor eq $auto_node->functor} $ref_par->get_echildren;
        next if (!$ref_eq);
        
        $ref_eq->add_aligned_node( $auto_node, 'monolingual.loose' );
        delete $auto_free->{$auto_node->id};
    }
}

1;

=head1 NAME

Treex::Block::Align::T::AlignGeneratedNodes

=head1 DESCRIPTION

A block for monolingual alignment of generated nodes, i.e. aligning
the generated nodes between gold and automatically analysed trees.
This block must be run on the zone with gold trees (usually "ref").

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

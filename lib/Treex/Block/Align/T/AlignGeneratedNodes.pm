package Treex::Block::Align::T::AlignGeneratedNodes;
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
);

sub process_zone {
    my ( $self, $src_zone ) = @_;
    my $trg_zone = $src_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    
    my @src_nodes = grep {$_->is_generated} $src_zone->get_ttree->get_descendants( { ordered => 1 } );
    my @trg_nodes = grep {$_->is_generated} $trg_zone->get_ttree->get_descendants( { ordered => 1 } );
    return if @trg_nodes == 0;

    my %trg_free = map { $_ => $_ } @trg_nodes;
    my %src_free = map { $_ => $_ } @src_nodes;

    while ((scalar (keys %trg_free) > 0) && (scalar (keys %src_free) > 0)) {
        my $max_score = 0;
        my ( @winners );

        foreach my $src_node ( values %src_free ) {
            foreach my $trg_node ( values %trg_free ) {
                my $score = $self->score( $src_node, $trg_node );
                if ( $score > $max_score ) {
                    $max_score  = $score;
                    @winners = ( [$src_node, $trg_node] );
                }
                elsif ( $score == $max_score ) {
                    push @winners, [$src_node, $trg_node];
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
            delete $src_free{$winner->[0]};
            delete $trg_free{$winner->[1]};
        }
    }
    return;
}

sub compare_aligned_nodes {
    my ($self, $src_nodes, $trg_nodes) = @_;
    my %trg_nodes_ids = map {$_->id => 1} @$trg_nodes;

    my @src_nodes_trg = map {
        $_->get_aligned_nodes_of_type('monolingual');
    } @$src_nodes;
    my $both_count = () = grep {$trg_nodes_ids{$_->id}} @src_nodes_trg;
    my $src_count = scalar @src_nodes_trg;
    my $trg_count = scalar @$trg_nodes;

    return 1 if (($src_count == 0) && ($trg_count == 0));
    return 2 * $both_count / ($src_count + $trg_count);
}

sub score {
    my ( $self, $src_node, $trg_node ) = @_;
    my %feature_vector;

    $feature_vector{lemma_equality} = $src_node->t_lemma eq $trg_node->t_lemma;

    my $src_par = $src_node->get_parent;
    
    $feature_vector{aligned_parent} = $src_par->is_directed_aligned_to($trg_node->get_parent, {rel_types => ['monolingual']}) ? 1 : 0;
    
    my @src_eparents = $src_node->get_eparents;
    my @trg_eparents = $trg_node->get_eparents;

    $feature_vector{aligned_eparents} = $self->compare_aligned_nodes(\@src_eparents, \@trg_eparents);

    my @src_siblings = $src_node->get_siblings;
    my @trg_siblings = $trg_node->get_siblings;

    $feature_vector{aligned_siblings} = $self->compare_aligned_nodes(\@src_siblings, \@trg_siblings);

    my $score = 0;
    foreach my $feature_name ( keys %feature_vector ) {
        $score += $feature_vector{$feature_name}
            * ( $weight{$feature_name} or log_fatal "Unknown feature $feature_name" );
    }

    return $score;
}

1;

# Copyright 2011 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Block::T2T::CS2CS::FixInfrequentFormemes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', required => 0 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );
has 'log_to_console'  => ( is       => 'rw', isa => 'Bool', default => 0 );

# model
has 'model'            => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has 'model_from_share' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );

# exclusive thresholds
has 'lower_threshold' => ( is => 'ro', isa => 'Num', default => 0.5 );
has 'upper_threshold' => ( is => 'ro', isa => 'Num', default => 0.5 );

my $model_data;

use Carp;

sub process_start {
    my $self = shift;

    # find the model file
    if ( defined $self->model_from_share ) {
        my $model = require_file_from_share( $self->model_from_share );
        $self->set_model($model);
    }
    if ( !defined $self->model ) {
        log_fatal("Either model or model_from_share parameter must be set!");
    }

    # load the model file
    $model_data = do $self->model;

    # handle errors
    if ( !$model_data ) {
        if ($@) {
            log_fatal "Cannot parse file " . $self->model . ": $@";
        }
        elsif ( !defined $model_data ) {
            log_fatal "Cannot read file " . $self->model . ": $!";
        }
        else {
            log_fatal "Cannot load data from file " . $self->model;
        }
    }

    return;
}

sub process_tnode {
    my ( $self, $node ) = @_;

    # get info about current node
    # TODO: cut the rubbish from the lemma since CzEng has simpler lemmas
    my $tlemma  = $node->t_lemma();
    my $ptlemma = $node->get_eparents( { first_only => 1, or_topological => 1 } )->t_lemma() || '';
    my $formeme = $node->formeme();

    # get info from model
    my $original_frequency = get_formeme_frequency(
        $model_data->{tlemma_ptlemma_formeme}->{$tlemma}->{$ptlemma}->{$formeme},
        $model_data->{tlemma_ptlemma}->{$tlemma}->{$ptlemma},
    );
    my $best_formeme = get_most_frequent_formeme(
        $model_data->{tlemma_ptlemma_formeme}->{$tlemma}->{$ptlemma},
    );
    my $best_frequency = get_formeme_frequency(
        $model_data->{tlemma_ptlemma_formeme}->{$tlemma}->{$ptlemma}->{$best_formeme},
        $model_data->{tlemma_ptlemma}->{$tlemma}->{$ptlemma},
    );

    # change the current formeme if it seems to be a good idea
    my $change = ( $original_frequency < $self->lower_threshold ) && ( $best_frequency > $self->upper_threshold );
    if ($change) {
        $node->set_formeme($best_formeme);

        # TODO: somehow regenerate the releant part of the a-tree
        # (at this stage probably only mark this node somehow and do the regeneration only after all t-layer fixes have been applied)
    }

    # log
    $self->logfix(
        $node,
        "current formeme: $formeme ($original_frequency); " .
            "best formeme: $best_formeme ($best_frequency): " .
            ( $change ? 'changing' : 'keeping' )
    );

    return;
}

sub get_formeme_frequency {
    my ( $formeme_count, $all_count ) = @_;

    if ($formeme_count) {
        return $formeme_count / $all_count;
    }
    else {
        return 0;
    }

}

sub get_most_frequent_formeme {
    my ($candidates) = @_;

    my $top_count   = 0;
    my $top_formeme = '';    # returned if no usable formemes in model
    foreach my $candidate ( keys %$candidates ) {
        my $count = $candidates->{$candidate};
        if ( $count > $top_count ) {
            $top_count   = $count;
            $top_formeme = $candidate;
        }
    }

    return $top_formeme;
}

sub logfix {
    my ( $self, $node, $msg ) = @_;

    # log to treex file
    my $fixzone = $node->get_bundle()->get_or_create_zone( $self->language, 'deepfix' );
    my $sentence = $fixzone->sentence;
    if ($sentence) {
        $sentence .= " [$msg]";
    }
    else {
        $sentence = "[$msg]";
    }
    $fixzone->set_sentence($sentence);

    # log to console
    if ( $self->log_to_console ) {
        log_info($msg);
    }

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::FixInfrequentFormemes -
An attempt to replace infrequent formemes by some mopre frequent ones.

=head1 DESCRIPTION

An attempt to replace infrequent formemes by some mopre frequent ones.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

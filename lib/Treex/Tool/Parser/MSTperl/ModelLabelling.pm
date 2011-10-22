package Treex::Tool::Parser::MSTperl::ModelLabelling;

use Moose;

extends 'Treex::Tool::Parser::MSTperl::ModelBase';

# transition probs:
#   transitions->{label_prev}->{label_this} = count
# unigram counts stored as:
#   transitions->{label_this}->{$config->UNIGRAM_PROB_KEY} = count
#
has 'transitions' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

# emission scores (maybe should be probabilities?):
#   weights->{feature}->{label} = weight
#
has 'weights' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    $self->featuresControl( $self->config->labelledFeaturesControl );

    return;
}

# STORING AND LOADING

sub get_data_to_store {
    my ($self) = @_;

    return {
        'transitions' => $self->transitions,
        'weights'     => $self->weights,
    };
}

sub load_data {

    my ( $self, $data ) = @_;

    $self->transitions( $data->{'transitions'} );
    $self->weights( $data->{'weights'} );

    if (scalar( keys %{ $self->transitions } )
        && scalar( keys %{ $self->weights } )
        )
    {
        return 1;
    } else {
        return 0;
    }
}

# TRANSITION COUNTS AND PROBABILITIES

sub add_transition {
    my ( $self, $label_this, $label_prev ) = @_;

    if ( $self->config->DEBUG >= 2 ) {
        print "add_transition($label_this, $label_prev)\n";
    }

    # increment sum of numbers of unigrams
    $self->transitions->{ $self->config->UNIGRAM_PROB_KEY } += 1;

    # increment number of unigrams
    $self->transitions->{$label_this}->
        { $self->config->UNIGRAM_PROB_KEY } += 1;
    if ($label_prev) {

        # increment number of bigrams
        $self->transitions->{$label_prev}->{$label_this} += 1;
    }

    return;
}

# called after preprocessing training data, before entering the MIRA phase
sub prepare_for_mira {

    my ($self) = @_;

    my $UNIGRAM_PROB_KEY = $self->config->UNIGRAM_PROB_KEY;

    # recompute transition counts to probabilities
    my $grandTotal = $self->transitions->{$UNIGRAM_PROB_KEY};
    foreach my $label ( keys %{ $self->transitions } ) {
        if ( $label eq $UNIGRAM_PROB_KEY ) { next; }

        # prob to assign to unigram $label
        my $label_prob = $self->transitions->{$label}->{$UNIGRAM_PROB_KEY}
            / $grandTotal;

        # count sum of next labels
        my $labelTotal = 0;
        foreach my $next_label ( keys %{ $self->transitions->{$label} } ) {
            $labelTotal += $self->transitions->{$label}->{$next_label};
        }

        # $UNIGRAM_PROB_KEY was not skipped, must be subtracted
        $labelTotal -= $self->transitions->{$label}->{$UNIGRAM_PROB_KEY};

        if ($labelTotal) {

            # assign transition probs
            foreach my $next_label ( keys %{ $self->transitions->{$label} } ) {
                $self->transitions->{$label}->{$next_label}
                    = $self->transitions->{$label}->{$next_label} / $labelTotal;
            }
        }

        # assign unigram prob
        $self->transitions->{$label}->{$UNIGRAM_PROB_KEY} = $label_prob;

        # create a probability table of labels under weights->UNIGRAM_PROB_KEY->
        # TODO: other weights are NOT probabilities, so these are uncomparable
        $self->weights->{$UNIGRAM_PROB_KEY}->{$label} = $label_prob;
    }

    delete $self->weights->{$UNIGRAM_PROB_KEY}
        ->{ $self->config->SEQUENCE_BOUNDARY_LABEL };

    if ( $self->config->DEBUG >= 2 ) {
        print "Label probabilities:\n";
        foreach my $label ( keys %{ $self->weights->{$UNIGRAM_PROB_KEY} } ) {
            print "$label: " . $self->weights->{$UNIGRAM_PROB_KEY}->{$label}
                . "\n";
        }
    }

    return;
}

sub get_transition_prob {

    # (Str $feature)
    my ( $self, $label_this, $label_prev ) = @_;

    if ($self->transitions->{$label_prev}
        && $self->transitions->{$label_prev}->{$label_this}
        )
    {
        return $self->transitions->{$label_prev}->{$label_this};
    } else {

        # TODO: provide some smoothing?
        return 0;
    }
}

# FEATURE WEIGHTS

# get weight for the feature and the label
sub get_feature_weight {

    # (Str $feature, Str $label)
    my ( $self, $feature, $label ) = @_;

    if ( $self->weights->{$feature} && $self->weights->{$feature}->{$label} ) {
        return $self->weights->{$feature}->{$label};
    } else {
        return 0;
    }
}

# for the given feature get a HashRef in the format ->{label}->weight
sub get_feature_weights {

    # (Str $feature)
    my ( $self, $feature ) = @_;

    my $weights = $self->weights->{$feature};
    if ($weights) {
        return $weights;
    } else {
        return;
    }
}

# get PROBABILITIES of all possible labels based on all the features
# (i.e. for each feature do get_feature_weights(), sum it together
# and recompute it to probabilities)
sub get_emission_probs {

    # (ArrayRef[Str] $features)
    my ( $self, $features ) = @_;

    my %result;

    # get scores
    foreach my $feature (@$features) {
        if ( $self->weights->{$feature} ) {
            foreach my $label ( keys %{ $self->weights->{$feature} } ) {
                $result{$label} += $self->weights->{$feature}->{$label};
            }
        }
    }

    # find min and max score
    # TODO: delete zeros?
    my $min = 1e300;
    my $max = -1e300;
    foreach my $label ( keys %result ) {
        if ( $result{$label} < $min ) {
            $min = $result{$label};
        } elsif ( $result{$label} > $max ) {
            $max = $result{$label};
        }

        # else is between $min and $max
    }

    # recompute scores to probs
    if ( $min < $max ) {

        # the typical case
        my $subtractant = $min;
        my $divisor     = $max - $min;

        # TODO: asigns zero probability to least probable labels,
        # should not do that (but what to do?!)
        foreach my $label ( keys %result ) {
            $result{$label} = ( $result{$label} - $min ) / $divisor;
        }
    } elsif ( $min == $max ) {

        # uniform prob distribution
        my $prob = 1 / scalar( keys %result );
        foreach my $label ( keys %result ) {
            $result{$label} = $prob;
        }
    } else {

        # $min > $max, i.e. nothing has been generated
        %result = %{ $self->weights->{ $self->config->UNIGRAM_PROB_KEY } };
    }

    return \%result;
}

# get score of assigning the edge with the given features the given label
# TODO: somehow include transition probs as well?
sub get_edge_score {

    # (Treex::Tool::Parser::MSTperl::Edge $edge, Str $label)
    my ( $self, $edge, $label ) = @_;

    my $result = 0;

    foreach my $feature ( @{ $edge->features } ) {
        $result += $self->get_feature_weight( $feature, $label );
    }

    return $result;
}

sub set_feature_weight {

    # (Str $feature, Num $weight, Str $label)
    my ( $self, $feature, $weight, $label ) = @_;

    $self->weights->{$feature}->{$label} = $weight;

    return;
}

sub update_feature_weight {

    # (Str $feature, Num $update, Str $label)
    my ( $self, $feature, $update, $label ) = @_;

    $self->weights->{$feature}->{$label} += $update;

    return;
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelLabelling

=head1 DESCRIPTION

This is an in-memory represenation of a labelling model,
extended from L<Treex::Tool::Parser::MSTperl::ModelBase>.

=head1 FIELDS

=head2 Feature weights

=over 4

=item 

=back

=head1 METHODS

=over 4

=item

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

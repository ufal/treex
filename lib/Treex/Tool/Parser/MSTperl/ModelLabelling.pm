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

sub get_feature_weight {

    # (Str $feature)
    #    my ( $self, $feature, $label ) = @_;
    my ( $self, $feature ) = @_;

    #    my $weight = $self->weights->{$feature}->{$label};
    my $weight = $self->weights->{$feature};
    if ($weight) {
        return $weight;
    } else {
        return 0;
    }
}

sub set_feature_weight {

    # (Str $feature, Num $weight)
    #    my ( $self, $feature, $label, $weight ) = @_;
    my ( $self, $feature, $weight ) = @_;

    #    $self->weights->{$feature}->{$label} = $weight;
    $self->weights->{$feature} = $weight;

    return;
}

sub update_feature_weight {

    # (Str $feature, Num $update)
    #    my ( $self, $feature, $label, $update ) = @_;
    my ( $self, $feature, $update ) = @_;

    #    $self->weights->{$feature}->{$label} += $update;
    $self->weights->{$feature} += $update;

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

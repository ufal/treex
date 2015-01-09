package Treex::Tool::Parser::MSTperl::ModelUnlabelled;

use Moose;

extends 'Treex::Tool::Parser::MSTperl::ModelBase';

# TODO: features indexed? (i.e. weights would be an ArrayRef etc.)
# It would help to push down the size of edge_features_cache
# (no speedup or slowdown is expected).
has 'weights' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    $self->featuresControl( $self->config->unlabelledFeaturesControl );

    return;
}

use List::Util "sum";

# normalize feature weights
# so that sum(w) = 0
# and sum(abs(w)) = 1
# TODO: works worse, so reverting back to ensuring only
# sum(abs(w)) = 1
sub normalize {
    my ($self) = @_;
    
    my @values = values(%{$self->weights});
    my $count = scalar( @values );
#     my $sum = sum( @values );
# 
#     # subtract fair share of sum
#     # so that the new weights sum to 0
#     my $subtrahend = $sum/$count;
#     foreach my $key (keys %{$self->weights}) {
#         $self->weights->{$key} = $self->weights->{$key} - $subtrahend; 
#     }
#     
#     @values = values(%{$self->weights});
    my $abssum = sum( map {abs} @values );

    # divide by the average absolute weight
    # so that the new average absolute weight is 1
#    my $divisor = $abssum/$count;
    my $divisor = $abssum;
    foreach my $key (keys %{$self->weights}) {
        $self->weights->{$key} = $self->weights->{$key} / $divisor;
    }

    return 1;
}

# STORING AND LOADING

sub get_data_to_store {
    my ($self) = @_;

    return $self->weights;
}

sub get_data_to_store_tsv {
    my ($self) = @_;

    my @result;
    foreach my $feature ( keys %{ $self->weights } ) {
        if ( $feature =~ /^([0-9]+):(.*)$/ ) {
            my $index       = $1;
            my $value       = $2;
            my $code        = $self->featuresControl->feature_codes->[$index];
            my $feature_str = "$code:$value";
            push @result, $feature_str . "\t" . $self->weights->{$feature};
        } else {
            print STDERR "Feature $feature is not in correct format!\n";
        }
    }

    return [@result];
}

sub load_data {

    my ( $self, $data ) = @_;

    $self->weights($data);

    if ( scalar( keys %{ $self->weights } ) ) {
        return 1;
    } else {
        return 0;
    }
}

sub load_data_tsv {

    my ( $self, $data ) = @_;

    my %weights;

    #precompute feature code to feature index translation table
    my %code2index;
    my $feature_num = $self->featuresControl->feature_count;
    for (
        my $feature_index = 0;
        $feature_index < $feature_num;
        $feature_index++
        )
    {
        my $code = $self->featuresControl->feature_codes->[$feature_index];
        $code2index{$code} = $feature_index;
    }

    foreach my $line (@$data) {
        my ( $feature, $weight ) = split /\t/, $line;
        if ( $feature =~ /^([^:]+):(.*)$/ ) {
            my $code            = $1;
            my $value           = $2;
            my $index           = $code2index{$code};
            my $feature_indexed = "$index:$value";
            $weights{$feature_indexed} = $weight;
        } else {
            print STDERR "Feature $feature is not in correct format!\n";
        }
    }

    $self->weights( \%weights );

    if ( scalar( keys %{ $self->weights } ) ) {
        return 1;
    } else {
        return 0;
    }
}

# FEATURE WEIGHTS

sub score_edge {

    # (Treex::Tool::Parser::MSTperl::Edge $edge)
    my ( $self, $edge ) = @_;

    my $features_rf = $self->featuresControl->get_all_features($edge);
    return $self->score_features($features_rf);
}

sub score_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    my $score = $self->score_features( $sentence->features );

    return $score;
}

sub score_features {

    # (ArrayRef[Str] $features)
    my ( $self, $features ) = @_;

    my $score = 0;
    foreach my $feature ( @{$features} ) {
        $score += $self->get_feature_weight($feature);
    }

    return $score;
}

sub get_feature_weight {

    # (Str $feature)
    my ( $self, $feature ) = @_;

    my $weight = $self->weights->{$feature};
    if ($weight) {
        return $weight;
    } else {
        return 0;
    }
}

sub feature_is_unknown {

    # (Str $feature)
    my ( $self, $feature ) = @_;

    my $weight = $self->weights->{$feature};
    if ($weight) {
        return 0;
    } else {
        return 1;
    }
}

sub set_feature_weight {

    # (Str $feature, Num $weight)
    my ( $self, $feature, $weight ) = @_;

    $self->weights->{$feature} = $weight;

    return;
}

sub update_feature_weight {

    # (Str $feature, Num $update)
    my ( $self, $feature, $update ) = @_;

    $self->weights->{$feature} += $update;

    return;
}

# returns number of features in the model
sub get_feature_count {
    my ($self) = @_;

    return scalar( keys %{ $self->weights } );
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelUnlabelled

=head1 DESCRIPTION

This is an in-memory represenation of a parsing model,
extended from L<Treex::Tool::Parser::MSTperl::ModelBase>.

The model is represented by features and their weights.

=head1 FIELDS

=head2 Feature weights

=over 4

=item weights

A hash reference containing weights of all features. This is the actual model.

=back

=head1 METHODS

=head2 Access to feature weights

=over 4

=item my $edge_score = $model->score_edge($edge);

Counts the score of an edge by summing up weights of all of its features.

=item my $sentence_score = $model->score_sentence($sentence)

Returns score of the sentence (by calling
C<score_features> on the sentence features).

=item my $score = $model->score_features(['0:být|VB', '1:pes|N1', ...]);

Counts the score of an edge or sentence by summing up weights of all of its
features, which are passed as an array reference.

=item my $feature_weight = $model->get_feature_weight('1:pes|N1');

Returns the weight of a given feature,
or C<0> if the feature is not contained in the model.

=item $model->set_feature_weight('1:pes|N1', 0.0021);

Sets a new weight for a given feature.

=item $model->update_feature_weight('1:pes|N1', 0.0042);

Adds the update value to current feature weight - eg. if the weight of the
feature C<'1:pes|N1'> is currently C<0.0021>, it will be C<0.0063> after the
call.
The update can also be negative - then the weight of the feature decreases.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

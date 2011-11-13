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

=head1 FIELDS

=head2 Feature weights

=over 4

=item weights

A hash reference containing weights of all features. This is the actual model.

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

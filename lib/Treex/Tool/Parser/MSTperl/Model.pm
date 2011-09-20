package Treex::Tool::Parser::MSTperl::Model;

use Data::Dumper;
use autodie;
use Moose;

has featuresControl => (
    isa      => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is       => 'ro',
    required => '1',
);

# TODO: features indexed? (i.e. weights would be an ArrayRef etc.)
# It would help to push down the size of edge_features_cache
# (no speedup or slowdown is expected).
has 'weights' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

# LOADING AND STORING

sub store {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    print "Saving model to '$filename'... ";

    open my $file, ">:encoding(utf8)", $filename;
    print $file Dumper $self->weights;
    close $file;

    print "Model saved.\n";

    return 1;
}

sub store_tsv {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    print "Saving model to '$filename'... ";

    open my $file, ">:encoding(utf8)", $filename;
    foreach my $feature ( keys %{ $self->weights } ) {
        if ( $feature =~ /^([0-9]+):(.*)$/ ) {
            my $index            = $1;
            my $value            = $2;
            my $code             = $self->featuresControl->feature_codes->[$index];
            my $feature_stringed = "$code:$value";
            print $file $feature_stringed . "\t" . $self->weights->{$feature} . "\n";
        } else {
            print STDERR "Feature $feature is not in correct format!\n";
        }
    }
    close $file;

    print "Model saved.\n";

    return 1;
}

sub load {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    print "Loading model from '$filename'...\n";

    my $weights = do $filename;
    $self->weights($weights);

    print "Model loaded.\n";

    return 1;
}

sub load_tsv {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    print "Loading model from '$filename'... ";

    my %weights;

    #precompute feature code to feature index translation table
    my %code2index;
    my $feature_num = $self->featuresControl->feature_count;
    for ( my $feature_index = 0; $feature_index < $feature_num; $feature_index++ ) {
        my $code = $self->featuresControl->feature_codes->[$feature_index];
        $code2index{$code} = $feature_index;
    }

    #read the file
    open my $file, '<:encoding(utf8)', $filename;
    while (<$file>) {
        chomp;
        my ( $feature, $weight ) = split /\t/;
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
    close $file;

    $self->weights( \%weights );

    print "Model loaded.\n";

    return 1;
}

# ACCESS TO FEATURES

sub score_edge {

    # (Treex::Tool::Parser::MSTperl::Edge $edge)
    my ( $self, $edge ) = @_;

    my $features_rf = $self->featuresControl->get_all_features($edge);
    return $self->score_features($features_rf);
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

# FEATURE WEGHTS

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

    return 1;
}

sub update_feature_weight {

    # (Str $feature, Num $update)
    my ( $self, $feature, $update ) = @_;

    $self->weights->{$feature} += $update;

    return 1;
}

1;

__END__

=head1 NAME

Treex::Tool::Parser::MSTperl::Model

=head1 DESCRIPTION

This is an in-memory represenation of a parsing model.
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

=item my $edge_score =
$model->score_edge($edge);

Counts the score of an edge by summing up weights of all of its features.

=item my $score =
$model->score_features(['0:být|VB', '1:pes|N1', ...]);

Counts the score of an edge or sentence by summing up weights of all of its features,
which are passed as an array reference.

=item my $feature_weight = $model->get_feature_weight('1:pes|N1');

Returns the weight of a given feature,
or C<0> if the feature is not contained in the model.

=item $model->set_feature_weight('1:pes|N1', 0.0021);

Sets a new weight for a given feature.

=item $model->update_feature_weight('1:pes|N1', 0.0042);

Adds the update value to current feature weight - eg. if the weight of the 
feature C<'1:pes|N1'> is currently C<0.0021>, it will be C<0.0063> after the
call. The update can also be negative - then the weight of the feature decreases.

=back

=head2 Loading and storing

=over 4

=item $model->load('modelfile.model');

Loads model (= loads feature weights) from file in L<Data::Dumper> format:

    $VAR1 = {
        '0:být|VB' => '0.0042',
        '1:pes|N1' => '0.0021',
        ...
    };

The feature codes are represented by their indexes in C<all_feature_codes>.

=item $model->load_tsv('modelfile.tsv');

Loads model from file in TSV (tab separated values) format:

        L|T:být|VB [tab] 0.0042
        l|t:pes|N1 [tab] 0.0021
        ...

The feature codes are written as text.

=item $model->store('modelfile.model');

Stores model into file in L<Data::Dumper> format.

=item $model->store_tsv('modelfile.tsv');

Stores model into file in TSV format:


=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

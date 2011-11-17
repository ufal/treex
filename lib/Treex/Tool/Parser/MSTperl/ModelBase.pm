package Treex::Tool::Parser::MSTperl::ModelBase;

use Data::Dumper;
use autodie;
use Moose;
use Carp;

has 'config' => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

has 'featuresControl' => (
    isa => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is  => 'rw',
);

# called after preprocessing training data, before entering the MIRA phase
sub prepare_for_mira {

    my ( $self, $trainer ) = @_;

    # nothing in the base, to be overridden in extending packages

    return;
}

# returns number of features in the model (where a "feature" can stand for
# various things depending on the algorithm used)
sub get_feature_count {
    my ($self) = @_;

    # nothing in the base, to be overridden in extending packages

    return 0;
}

# LOADING AND STORING

sub store {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    if ( $self->config->DEBUG >= 1 ) {
        print "Saving model to '$filename'... ";
    }

    open my $file, ">:encoding(utf8)", $filename;
    print $file Dumper $self->get_data_to_store();
    close $file;

    if ( -e $filename ) {
        if ( $self->config->DEBUG >= 1 ) {
            print "Model saved.\n";
        }
        return 1;
    } else {
        croak "MSTperl parser error:"
            . "unable to create the model file '$filename'!";
    }
}

sub get_data_to_store {
    my ($self) = @_;

    croak 'abstract method get_data_to_store to be overridden' .
        ' and called on extending packages!';
}

sub store_tsv {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    if ( $self->config->DEBUG >= 1 ) {
        print "Saving model to '$filename'... ";
    }

    open my $file, ">:encoding(utf8)", $filename;
    print $file join "\n", @{ $self->get_data_to_store_tsv() };
    close $file;

    if ( -e $filename ) {
        if ( $self->config->DEBUG >= 1 ) {
            print "Model saved.\n";
        }
        return 1;
    } else {
        croak "MSTperl parser error:"
            . "unable to create the model file '$filename'!";
    }
}

sub get_data_to_store_tsv {
    my ($self) = @_;

    croak 'abstract method get_tsv_data_to_store to be overridden' .
        ' and called on extending packages!';
}

sub load {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    if ( $self->config->DEBUG >= 1 ) {
        print "Loading model from '$filename'...\n";
    }

    my $data   = do $filename;
    my $result = $self->load_data($data);

    if ($result) {
        if ( $self->config->DEBUG >= 1 ) {
            print "Model loaded.\n";
        }
        return 1;
    } else {
        croak "MSTperl parser error:"
            . "model file data error!";
    }
}

sub load_data {
    my ( $self, $data ) = @_;

    croak 'abstract method load_data to be overridden' .
        ' and called on extending packages!';

}

sub load_tsv {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    if ( $self->config->DEBUG >= 1 ) {
        print "Loading model from '$filename'... ";
    }

    my @data;

    #read the file
    open my $file, '<:encoding(utf8)', $filename;
    while (<$file>) {
        chomp;
        push @data, $_;
    }
    close $file;

    my $result = $self->load_data_tsv( [@data] );

    if ($result) {
        if ( $self->config->DEBUG >= 1 ) {
            print "Model loaded.\n";
        }
        return 1;
    } else {
        croak "MSTperl parser error:"
            . "model file data error!";
    }
}

sub load_data_tsv {
    my ( $self, $data ) = @_;

    croak 'abstract method load_tsv_data to be overridden' .
        ' and called on extending packages!';

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

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelBase

=head1 DESCRIPTION

TODO: outdated; some of the information should be moved to ModelUnlabelled
and some should be added

This is a base class for an in-memory represenation of a parsing or labelling
model.
The model is represented by features and their weights.

=head1 FIELDS

=over 4

=item config

=item featuresControl

=back

=head1 METHODS

=head2 Access to feature weights

=over 4

=item my $edge_score =
$model->score_edge($edge);

Counts the score of an edge by summing up weights of all of its features.

=item my $score =
$model->score_features(['0:být|VB', '1:pes|N1', ...]);

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

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

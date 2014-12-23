package Treex::Tool::Parser::MSTperl::ModelBase;

use Data::Dumper;
use autodie;
use Moose;
use Carp;

require File::Temp;
use File::Temp ();
use File::Temp qw/ :seekable /;

has 'config' => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

has 'featuresControl' => (
    isa => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is  => 'rw',
);

# sum of all feature weights
# to be used for normalizing
# TODO: if this proves useful, normalize all features immediately,
# either after loaing the model or even immediately after training the model
has normalization => ( is => 'rw', isa => 'Num', lazy => 1, builder => '_build_normalization' );

has weight => ( is => 'rw', isa => 'Num', default => 1 );

sub _build_normalization {
    my ($self) = @_;

    return 1;
}

# called after preprocessing training data, before entering the MIRA phase
sub prepare_for_mira {

    # my ( $self, $trainer ) = @_;

    # nothing in the base, to be overridden in extending packages

    return;
}

# returns number of features in the model (where a "feature" can stand for
# various things depending on the algorithm used)
sub get_feature_count {

    # my ($self) = @_;

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

    # my ($self) = @_;

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

    # my ($self) = @_;

    croak 'abstract method get_tsv_data_to_store to be overridden' .
        ' and called on extending packages!';
}

sub load {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    if ( $self->config->DEBUG >= 1 ) {
        print "Loading model from '$filename'...\n";
    }

    my $tmpfile;
    if ( $filename =~ /\.gz$/ ) {
        $tmpfile = File::Temp->new( UNLINK => 1 );
        system "gunzip -c $filename > $tmpfile";
        $filename = $tmpfile->filename;
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

    # my ( $self, $data ) = @_;

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

    # my ( $self, $data ) = @_;

    croak 'abstract method load_tsv_data to be overridden' .
        ' and called on extending packages!';

}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelBase

=head1 DESCRIPTION

This is a base class for an in-memory represenation of a parsing or labelling
model.

=head1 FIELDS

=over 4

=item config

Instance of L<Treex::Tool::Parser::MSTperl::Config> containing settings to be
used for the model.

=item featuresControl

Provides access to features, especially enabling their computation.
Intance of L<Treex::Tool::Parser::MSTperl::FeaturesControl>.

=back

=head1 METHODS

=head2 Loading and storing

=over 4

=item $model->load('modelfile.model');

Loads model from file in L<Data::Dumper> format, eg.:

    $VAR1 = {
        '0:být|VB' => '0.0042',
        '1:pes|N1' => '0.0021',
        ...
    };

The feature codes are represented by their indexes
(see L<Treex::Tool::Parser::MSTperl::FeaturesControl/simple_feature_codes>).

=item $model->load_tsv('modelfile.tsv');

Loads model from file in TSV (tab separated values) format, eg.:

        L|T:být|VB [tab] 0.0042
        l|t:pes|N1 [tab] 0.0021
        ...

The feature codes are written as text.

=item $model->store('modelfile.model');

Stores model into file in L<Data::Dumper> format.

=item $model->store_tsv('modelfile.tsv');

Stores model into file in TSV format:

=back

=head3 Method stubs to be overridden in extending packages.

=over 4

=item $data = get_data_to_store(), $data = get_data_to_store_tsv()

Returns the data that form the model to be saved to a model file.

=item load_data($data), load_data_tsv($data)

Fills the model with model data acquired from a model file.

=back

=head2 Training support

=head3 Method stubs to be overridden in extending packages.

=over 4

=item prepare_for_mira

Called after preprocessing training data, before entering the MIRA phase.

=item get_feature_count

Only to provide information about the model.
Returns number of features in the model (where a "feature" can stand for
various things depending on the algorithm used).

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

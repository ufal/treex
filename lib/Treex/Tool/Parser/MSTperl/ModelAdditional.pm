package Treex::Tool::Parser::MSTperl::ModelAdditional;

use Data::Dumper;
use 5.010;
use autodie;
use Moose;
use Carp;

require File::Temp;
use File::Temp ();
use File::Temp qw/ :seekable /;

has config => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

has model => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has model_file => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

has model_format => (
    is      => 'ro',
    isa     => 'Str',
    default => 'tsv',
);

has 'buckets' => (
    is      => 'rw',
    isa     => 'Maybe[ArrayRef[Int]]',
    default => undef,
    trigger => \&_buckets_set,
);

# sets value2bucket, maxBucket and minBucket
sub _buckets_set {
    my ( $self, $buckets ) = @_;

    if ( !defined $buckets ) {
        return;
    }

    my %value2bucket;
    $value2bucket{'?'} = '?';

    # find maximal and minimal bucket & partly fill %value2bucket
    my $minBucket = -1000;
    my $maxBucket = 1000;
    foreach my $bucket ( @{$buckets} ) {
        if ( $value2bucket{$bucket} ) {
            warn "Bucket '$bucket' is defined more than once; "
                . "disregarding its later definitions.\n";
        }
        elsif ( $bucket > 0 ) {
            croak "MSTperl config file error: "
                . "Error on bucket '$bucket' - "
                . "buckets must be negative integers.";
        }
        else {
            $value2bucket{$bucket} = $bucket;
            if ( $bucket > $maxBucket ) {
                $maxBucket = $bucket;
            }
            elsif ( $bucket < $minBucket ) {
                $minBucket = $bucket;
            }
        }
    }

    # set maxBucket and minBucket
    $self->maxBucket($maxBucket);
    $self->minBucket($minBucket);

    # fill %value2bucket from minBucket to maxBucket
    my $lastBucket = $minBucket;
    for ( my $value = $minBucket + 1; $value < $maxBucket; $value++ ) {
        if ( defined $value2bucket{$value} ) {

            # the value defines a bucket
            $lastBucket = $value2bucket{$value};
        }
        else {

            # the value falls into the highest lower bucket
            $value2bucket{$value} = $lastBucket;
        }
    }
    $self->value2bucket( \%value2bucket );

    return;
}

has 'value2bucket' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { { '?' => '?' } },
);

# if mapping is not found in the hash, maxBucket or minBucket is used
# -17 is the default as it seems to be the most frequent value
# (if no buckets are set. always -17 or '?' are returned)

# any higher value falls into this bucket
has 'maxBucket' => (
    isa     => 'Int',
    is      => 'rw',
    default => '-17',
);

# any lower value falls into this bucket
has 'minBucket' => (
    isa     => 'Int',
    is      => 'rw',
    default => '-17',
);

sub load {

    my ($self) = @_;

    if ( $self->config->DEBUG >= 1 ) {
        print "Loading additional model from '" . $self->model_file . "...\n";
    }

    my $result = undef;
    if ( $self->model_format eq 'tsv' ) {
        $result = $self->load_tsv( $self->model_file );
    }

    # probably TODO
    #    } elsif ( $self->model_format eq 'tsv.gz' ) {
    #        my $tmpfile = File::Temp->new( UNLINK => 1 );
    #        system "gunzip -c $filename > $tmpfile";
    #        $filename = $tmpfile->filename;
    #    }
    else {
        croak "Model format " . $self->model_format . " is not supported!";
    }

    if ($result) {
        if ( $self->config->DEBUG >= 1 ) {
            print "Additional model loaded.\n";
        }
        return 1;
    }
    else {
        croak "MSTperl parser error: additional model file data error!";
    }
}

sub load_tsv {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    {
        open my $file, '<:encoding(UTF-8)', $filename;
        my $line;
        while ( $line = <$file> ) {
            chomp $line;
            my ( $child, $parent, $value ) = split /\t/, $line;
            $self->model->{$child}->{$parent} = $value;
        }
        close $file;
    }

    return 1;
}

sub get_value {
    my ( $self, $child, $parent ) = @_;

    my $value = $self->model->{$child}->{$parent};
    if ( !defined $value ) {
        $value = '?';
    }

    return $value;
}

sub get_rounded_value {
    my ( $self, $child, $parent, $rounding ) = @_;

    my $value = $self->model->{$child}->{$parent};
    if ( defined $value ) {

        # get the rounding coefficient
        if ( !defined $rounding ) {
            $rounding = 0;
        }
        my $coef = 1;
        for ( my $i = 0; $i < $rounding; $i++ ) {
            $coef *= 10;
        }

        # get the value
        $value = int( $value * $coef ) / $coef;
    }
    else {
        $value = '?';
    }

    return $value;
}

sub get_bucketed_value {
    my ( $self, $child, $parent ) = @_;

    my $value = $self->get_rounded_value( $child, $parent );
    my $bucket = $self->value2bucket->{$value};
    if ( !defined $bucket ) {
        if ( $value <= $self->minBucket ) {
            $bucket = $self->minBucket;
        }
        else {

            # assert $value > $self->maxBucket
            $bucket = $self->maxBucket;
        }
    }

    return $bucket;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelAdditional

=head1 DESCRIPTION

A model containing edge PMI, i.e.
PMI[c,p] = log #[c,p] / #([c,*])#([*,p])
where c=child and p=parent

=head1 FIELDS

=head2 Public Fields

=over 4

=item model_file

The file containing the model,
i.e. a TSV file in the format
child[tab]parent[tab]PMI

=item model_format

Currently only tsv is supported.
TODO support tsv.gz, probably also Data Dumper model.

=item buckets

(A reference to) an array of buckets that PMI is bucketed into
(negative integers, do not have to be sorted).
The PMI is first ceiled,
and then it falls into the nearest lower bucket;
(if there is no such bucket, falls into the lowest one).

=back

=head2 Internal Fields

=over 4

=item model

In-memory representation of the model file,
in the format model->{child}->{parent} = PMI.

=item minBucket

The lowest bucket (a bin for all PMIs lower than that).

=item maxBucket

The highest bucket (a bin for all PMIs higher than that).

=item value2bucket

Provides fast conversion of ceiled PMIs
that are between minBucket and maxBucket
to buckets.

=back

=head1 METHODS

=over 4

=item load

=item get_value($child, $parent)

Returns the real PMI, i.e. a negative float
(there are hundreds of thousands of possible values).

Returns '?' if PMI is unknown.

=item get_rounded_value($child, $parent)

Returns ceiled PMI, i.e. the integer part of the real PMI
(there are about 30 possible values).

Returns '?' if PMI is unknown.

=item get_bucketed_value($child, $parent)

Returns the nearest bucket that is lower or equal
to the ceiled value of the PMI,
or the lowest existing bucket if the value is even lower.

Returns '?' if PMI is unknown.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
